"""Sugiere la categoría de movimientos importados a partir de su descripción.

Primero aprende del propio usuario (cómo categorizó antes descripciones iguales o parecidas) y,
si no hay historial, usa palabras clave de comercios habituales en Colombia y Latinoamérica,
que se asignan a la categoría del usuario con ese nombre (si la tiene).
"""

import re
import unicodedata
import uuid
from collections import Counter, defaultdict
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Category, CategoryKind, Transaction, TransactionType
from app.schemas.transaction import CategorizeItem, CategorySuggestion

HISTORY_LIMIT = 3000  # movimientos categorizados más recientes que se tienen en cuenta

# Palabras clave (sin tildes, en minúsculas) → nombre de categoría sugerida
KEYWORDS: dict[CategoryKind, dict[str, tuple[str, ...]]] = {
    CategoryKind.expense: {
        "Transporte": (
            "uber",
            "didi",
            "cabify",
            "indriver",
            "beat",
            "taxi",
            "peaje",
            "parqueadero",
            "parking",
            "gasolina",
            "terpel",
            "primax",
            "texaco",
            "biomax",
            "transmilenio",
            "tullave",
            "sitp",
            "avianca",
            "latam",
            "wingo",
            "viva air",
        ),
        "Comida": (
            "rappi",
            "ifood",
            "domicilio",
            "restaurante",
            "mcdonald",
            "burger king",
            "kfc",
            "frisby",
            "crepes",
            "el corral",
            "subway",
            "dominos",
            "papa johns",
            "juan valdez",
            "tostao",
            "starbucks",
            "oma",
            "panaderia",
            "cafe",
            "pizza",
        ),
        "Supermercado": (
            "exito",
            "carulla",
            "d1",
            "ara",
            "jumbo",
            "olimpica",
            "makro",
            "pricesmart",
            "metro supermercado",
            "colsubsidio",
            "surtimax",
            "isimo",
            "justo y bueno",
            "supermercado",
            "mercado",
        ),
        "Suscripciones": (
            "netflix",
            "spotify",
            "disney",
            "hbo",
            "max",
            "prime video",
            "amazon prime",
            "youtube",
            "apple com",
            "icloud",
            "google one",
            "google storage",
            "chatgpt",
            "openai",
            "claude",
            "anthropic",
            "deezer",
            "crunchyroll",
            "paramount",
            "canva",
        ),
        "Servicios": (
            "epm",
            "codensa",
            "enel",
            "vanti",
            "gas natural",
            "acueducto",
            "aguas",
            "claro",
            "movistar",
            "tigo",
            "etb",
            "wom",
            "une",
            "internet",
            "energia",
            "celsia",
            "emcali",
        ),
        "Vivienda": ("arriendo", "arrendamiento", "administracion", "inmobiliaria", "hipoteca"),
        "Salud": (
            "farmacia",
            "drogueria",
            "cruz verde",
            "farmatodo",
            "colsanitas",
            "sura",
            "eps",
            "clinica",
            "hospital",
            "medico",
            "odontologia",
            "laboratorio",
        ),
        "Educación": (
            "universidad",
            "colegio",
            "matricula",
            "curso",
            "platzi",
            "udemy",
            "coursera",
            "duolingo",
            "libreria",
        ),
        "Ocio": (
            "cine",
            "cinecolombia",
            "cine colombia",
            "procinal",
            "cinemark",
            "steam",
            "playstation",
            "xbox",
            "nintendo",
            "bar",
            "tuboleta",
            "eticket",
            "concierto",
        ),
        "Ropa": ("zara", "h m", "arturo calle", "koaj", "studio f", "tennis", "adidas", "nike"),
        "Mascotas": ("veterinaria", "mascota", "petco", "laika", "puppis"),
        "Impuestos": ("dian", "impuesto", "predial", "vehicular", "4x1000", "gmf"),
    },
    CategoryKind.income: {
        "Nómina": ("nomina", "salario", "sueldo", "pago nomina", "quincena"),
        "Intereses": ("intereses", "rendimientos", "rendimiento", "cdt"),
        "Reembolsos": ("reembolso", "devolucion", "reverso", "cashback"),
    },
}

_STOPWORDS = {
    "pago",
    "compra",
    "pse",
    "transferencia",
    "transf",
    "de",
    "del",
    "la",
    "el",
    "en",
    "por",
    "con",
    "para",
    "los",
    "las",
    "a",
    "y",
    "sa",
    "sas",
    "ltda",
    "col",
    "co",
    "bogota",
    "medellin",
    "cali",
    "www",
    "com",
    "tarjeta",
    "debito",
    "credito",
    "nequi",
    "bancolombia",
    "davivienda",
}


def normalize(text: str) -> str:
    plain = unicodedata.normalize("NFKD", text.lower())
    plain = "".join(c for c in plain if not unicodedata.combining(c))
    plain = re.sub(r"[^a-z0-9 ]", " ", plain)
    plain = re.sub(r"\b\d+\b", " ", plain)  # números de referencia, fechas, cuotas…
    return re.sub(r"\s+", " ", plain).strip()


def tokens(text: str) -> list[str]:
    return [t for t in normalize(text).split() if len(t) >= 3 and t not in _STOPWORDS]


def _contains(haystack: str, needle: str) -> bool:
    return f" {needle} " in f" {haystack} "


async def suggest(
    session: AsyncSession, user_id: uuid.UUID, items: list[CategorizeItem]
) -> list[CategorySuggestion]:
    categories = (await session.scalars(select(Category).where(Category.user_id == user_id))).all()
    by_name = {(normalize(c.name), c.kind): c.id for c in categories}

    rows = await session.execute(
        select(Transaction.description, Transaction.type, Transaction.category_id)
        .where(
            Transaction.user_id == user_id,
            Transaction.category_id.is_not(None),
            Transaction.type != TransactionType.transfer,
        )
        .order_by(Transaction.occurred_on.desc())
        .limit(HISTORY_LIMIT)
    )
    exact: dict[tuple[str, str], Counter[uuid.UUID]] = defaultdict(Counter)
    by_token: dict[tuple[str, str], Counter[uuid.UUID]] = defaultdict(Counter)
    for description, ttype, category_id in rows:
        assert category_id is not None
        exact[(normalize(description), ttype)][category_id] += 1
        for tok in set(tokens(description)):
            by_token[(tok, ttype)][category_id] += 1

    out: list[CategorySuggestion] = []
    for item in items:
        kind = CategoryKind.income if item.amount > Decimal(0) else CategoryKind.expense
        text = normalize(item.description)
        if not text:
            out.append(CategorySuggestion())
            continue

        seen = exact.get((text, kind.value))
        if seen:
            out.append(CategorySuggestion(category_id=seen.most_common(1)[0][0], source="history"))
            continue

        votes: Counter[uuid.UUID] = Counter()
        for tok in set(tokens(item.description)):
            counter = by_token.get((tok, kind.value))
            if counter:
                total = sum(counter.values())
                best, hits = counter.most_common(1)[0]
                # Solo palabras que casi siempre van a la misma categoría
                if hits / total >= 0.7:
                    votes[best] += hits
        if votes:
            out.append(CategorySuggestion(category_id=votes.most_common(1)[0][0], source="history"))
            continue

        match: uuid.UUID | None = None
        for name, words in KEYWORDS[kind].items():
            category_id = by_name.get((normalize(name), kind))
            if category_id and any(_contains(text, w) for w in words):
                match = category_id
                break
        out.append(CategorySuggestion(category_id=match, source="keyword" if match else None))
    return out
