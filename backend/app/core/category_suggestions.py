"""Categorías que la app sugiere crear con un clic. No se guardan por sí solas: el usuario elige."""

SUGGESTED_CATEGORIES: dict[str, tuple[str, ...]] = {
    "expense": (
        "Comida",
        "Supermercado",
        "Transporte",
        "Vivienda",
        "Servicios",
        "Salud",
        "Educación",
        "Ocio",
        "Ropa",
        "Suscripciones",
        "Mascotas",
        "Regalos",
        "Impuestos",
    ),
    "income": (
        "Nómina",
        "Ventas",
        "Trabajos extra",
        "Intereses",
        "Reembolsos",
        "Regalos recibidos",
    ),
}
