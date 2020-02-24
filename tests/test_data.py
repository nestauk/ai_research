import pytest
from unittest import mock

from ai_research.mag.query_mag_composite import build_expr
from ai_research.mag.query_mag_composite import query_mag_api
from ai_research.mag.query_mag_composite import build_composite_expr
from ai_research.mag.query_mag_composite import build_composite_expr_date


class TestBuildExpr:
    def test_build_expr_correctly_forms_query(self):
        assert list(build_expr([1, 2], "Id", 1000)) == ["expr=OR(Id=1,Id=2)"]
        assert list(build_expr(["cat", "dog"], "Ti", 1000)) == [
            "expr=OR(Ti='cat',Ti='dog')"
        ]

    def test_build_expr_respects_query_limit_and_returns_remainder(self):
        assert list(build_expr([1, 2, 3], "Id", 21)) == [
            "expr=OR(Id=1,Id=2)",
            "expr=OR(Id=3)",
        ]


def test_build_composite_queries_correctly():
    assert (
        build_composite_expr(["dog", "cat"], "F.FN", 2000)
        == "expr=OR(And(Composite(F.FN='dog'), Y>=2000), And(Composite(F.FN='cat'), Y>=2000))"
    )


def test_build_composite_by_date_queries_correctly():
    assert (
        build_composite_expr_date(
            ["dog", "cat"], "F.FN", 2000, (("01", "06"), ("01", "01"))
        )
        == "expr=OR(And(Composite(F.FN='dog'), D=['2000-01-01','2000-06-01']), And(Composite(F.FN='cat'), D=['2000-01-01','2000-06-01']))"
    )


@mock.patch("ai_research.mag.query_mag_composite.requests.post", autospec=True)
def test_query_mag_api_sends_correct_request(mocked_requests):
    sub_key = 123
    fields = ["Id", "Ti"]
    expr = "expr=OR(And(Composite(F.FN='dog'), Y>=2000), And(Composite(F.FN='cat'), Y>=2000))"
    query_mag_api(expr, fields, sub_key, query_count=10, offset=0)
    expected_call_args = mock.call(
        "https://api.labs.cognitive.microsoft.com/academic/v1.0/evaluate",
        data=b"expr=OR(And(Composite(F.FN='dog'), Y>=2000), And(Composite(F.FN='cat'), Y>=2000))&count=10&offset=0&model=latest&attributes=Id,Ti",
        headers={
            "Ocp-Apim-Subscription-Key": 123,
            "Content-Type": "application/x-www-form-urlencoded",
        },
    )
    assert mocked_requests.call_args == expected_call_args
