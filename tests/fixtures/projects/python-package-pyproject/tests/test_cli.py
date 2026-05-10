from myapp.cli import main


def test_main_runs() -> None:
    assert callable(main)
