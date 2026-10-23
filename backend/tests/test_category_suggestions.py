from httpx import AsyncClient

from app.core.category_suggestions import SUGGESTED_CATEGORIES

H = dict[str, str]


async def test_lists_suggestions_for_both_kinds(client: AsyncClient) -> None:
    r = await client.get("/api/v1/categories/suggestions")
    assert r.status_code == 200
    body = r.json()
    assert body["expense"] == list(SUGGESTED_CATEGORIES["expense"])
    assert body["income"] == list(SUGGESTED_CATEGORIES["income"])
    assert len(body["expense"]) > 5 and len(body["income"]) > 3


async def test_suggestions_have_no_duplicates_and_fit_the_name_limit() -> None:
    for names in SUGGESTED_CATEGORIES.values():
        assert len({n.lower() for n in names}) == len(names)
        assert all(1 <= len(n) <= 80 for n in names)


async def test_a_suggestion_can_be_created_as_a_normal_category(
    client: AsyncClient, auth: H
) -> None:
    name = SUGGESTED_CATEGORIES["expense"][0]
    r = await client.post(
        "/api/v1/categories", headers=auth, json={"name": name, "kind": "expense"}
    )
    assert r.status_code == 201
    names = [c["name"] for c in (await client.get("/api/v1/categories", headers=auth)).json()]
    assert names == [name]
