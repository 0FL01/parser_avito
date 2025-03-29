import pytest
from parser_cls import AvitoParse
from unittest.mock import MagicMock

# Basic test to ensure AvitoParse can be instantiated
def test_avito_parse_initialization():
    """
    Tests basic initialization of the AvitoParse class.
    Uses mocks for external dependencies like DB and XLSX handlers.
    """
    mock_db_handler = MagicMock()
    mock_xlsx_handler = MagicMock()
    mock_stop_event = MagicMock()

    # Minimal required parameters for initialization
    parser = AvitoParse(
        url="http://example.com",
        count=10,
        stop_event=mock_stop_event,
        db_handler=mock_db_handler,
        xlsx_handler=mock_xlsx_handler
    )

    assert isinstance(parser, AvitoParse)
    assert parser.url == "http://example.com"
    assert parser.count == 10
    assert parser.stop_event == mock_stop_event
    assert parser.db_handler == mock_db_handler
    assert parser.xlsx_handler == mock_xlsx_handler