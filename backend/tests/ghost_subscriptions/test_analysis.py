from datetime import date
from decimal import Decimal

from app.schemas.ghost_subscriptions import AlertKind, Cadence
from app.services.ghost_subscriptions import Charge, analyze, merchant_key

TODAY = date(2026, 10, 21)


def charge(description: str, amount: str, day: str, currency: str = "EUR") -> Charge:
    return Charge(description, Decimal(amount), date.fromisoformat(day), currency)


def monthly(description: str, amount: str, days: list[str]) -> list[Charge]:
    return [charge(description, amount, d) for d in days]


NETFLIX_DAYS = ["2026-07-05", "2026-08-05", "2026-09-05", "2026-10-05"]


def test_merchant_key_ignores_noise() -> None:
    assert merchant_key("NETFLIX 4521 *MAR") == "netflix mar"
    assert merchant_key("Café  Año—Nuevo") == "cafe ano nuevo"
    assert merchant_key("1234 ** 99") == ""


def test_detects_untracked_monthly_subscription() -> None:
    report = analyze(monthly("Netflix", "10.99", NETFLIX_DAYS), set(), TODAY)
    [sub] = report.subscriptions
    assert sub.cadence == Cadence.monthly
    assert sub.typical_amount == Decimal("10.99")
    assert sub.monthly_cost == Decimal("10.99")
    assert sub.next_expected == date(2026, 11, 5)
    assert sub.occurrences == 4
    assert not sub.tracked
    assert [(t.currency, t.total) for t in report.untracked_monthly] == [("EUR", Decimal("10.99"))]
    assert report.alerts == []


def test_tracked_subscription_is_not_counted_as_ghost() -> None:
    report = analyze(monthly("Netflix", "10.99", NETFLIX_DAYS), {"netflix"}, TODAY)
    assert report.subscriptions[0].tracked
    assert report.untracked_monthly == []


def test_irregular_purchases_are_not_subscriptions() -> None:
    days = ["2026-07-02", "2026-07-19", "2026-09-30", "2026-10-11"]
    assert analyze(monthly("Supermercado", "40", days), set(), TODAY).subscriptions == []


def test_cancelled_subscription_is_dropped() -> None:
    old = ["2026-01-05", "2026-02-05", "2026-03-05", "2026-04-05"]
    assert analyze(monthly("Gimnasio", "30", old), set(), TODAY).subscriptions == []


def test_yearly_and_weekly_cadences() -> None:
    yearly = [charge("Seguro", "120", "2025-03-01"), charge("Seguro", "120", "2026-03-01")]
    weekly = [
        charge("Clase", "5", d) for d in ("2026-09-23", "2026-09-30", "2026-10-07", "2026-10-14")
    ]
    report = analyze(yearly + weekly, set(), TODAY)
    by_name = {s.name: s for s in report.subscriptions}
    assert by_name["Seguro"].cadence == Cadence.yearly
    assert by_name["Seguro"].monthly_cost == Decimal("10.00")
    assert by_name["Clase"].cadence == Cadence.weekly
    assert by_name["Clase"].monthly_cost == Decimal("21.67")  # 5 * 52 / 12


def test_silent_price_increase() -> None:
    charges = monthly("Netflix", "10.99", NETFLIX_DAYS[:3]) + [
        charge("Netflix", "12.99", "2026-10-05")
    ]
    alerts = analyze(charges, set(), TODAY).alerts
    [alert] = [a for a in alerts if a.kind == AlertKind.price_increase]
    assert alert.previous_amount == Decimal("10.99")
    assert alert.amount == Decimal("12.99")
    assert alert.change_percent == Decimal("18.20")


def test_small_fluctuation_is_not_a_price_increase() -> None:
    charges = monthly("Netflix", "10.99", NETFLIX_DAYS[:3]) + [
        charge("Netflix", "11.10", "2026-10-05")
    ]
    assert analyze(charges, set(), TODAY).alerts == []


def test_duplicate_charge() -> None:
    charges = [charge("Spotify", "9.99", "2026-10-10"), charge("Spotify", "9.99", "2026-10-11")]
    [alert] = analyze(charges, set(), TODAY).alerts
    assert alert.kind == AlertKind.duplicate
    assert alert.amount == Decimal("9.99")


def test_same_amount_far_apart_is_not_a_duplicate() -> None:
    charges = [charge("Spotify", "9.99", "2026-09-10"), charge("Spotify", "9.99", "2026-10-10")]
    assert analyze(charges, set(), TODAY).alerts == []


def test_free_trial_turned_paid() -> None:
    charges = [
        charge("Streaming", "1.00", "2026-09-20"),
        charge("Streaming", "11.99", "2026-10-15"),
    ]
    [alert] = analyze(charges, set(), TODAY).alerts
    assert alert.kind == AlertKind.trial_converted
    assert alert.previous_amount == Decimal("1.00")
    assert alert.amount == Decimal("11.99")


def test_currencies_are_never_mixed() -> None:
    eur = monthly("Netflix", "10.99", NETFLIX_DAYS)
    usd = [Charge("Netflix", Decimal("12"), c.day, "USD") for c in eur]
    report = analyze(eur + usd, set(), TODAY)
    assert {s.currency for s in report.subscriptions} == {"EUR", "USD"}
    assert len(report.untracked_monthly) == 2
