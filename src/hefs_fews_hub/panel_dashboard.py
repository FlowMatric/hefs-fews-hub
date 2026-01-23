# import debugpy; debugpy.listen(5678); debugpy.wait_for_client() # noqa
import contextlib
import json
from pathlib import Path

import panel as pn
from ipyleaflet import Map, GeoJSON

from hefs_fews_hub.dashboard_funcs import install_fews_standalone

with contextlib.suppress(Exception):
    from hefs_fews_hub.dashboard_funcs import (
        create_start_standalone_command,
        write_shell_file,
        s3_download_file,
        write_fews_desktop_shortcut,
        s3_download_directory_cli,
        set_up_logger
    )

pn.extension("ipywidgets", sizing_mode="stretch_width")

ACCENT_BASE_COLOR = "#5d6d7e"
RFC_BOUNDARIES = Path(__file__).parent / "geo" / "rfc_boundaries.geojson"
FEWS_INSTALL_DIR = Path("/opt", "fews")
MAP_CENTER_X = 38.80
MAP_CENTER_Y = -99.14
BUCKET_NAME = "ciroh-rti-hefs-data"
RFC_IDS = [
    "ABRFC",
    "APRFC",
    "CBRFC",
    "CNRFC",
    "LMRFC",
    "MARFC",
    "MBRFC",
    "NCRFC",
    "NERFC",
    "NWRFC",
    "OHRFC",
    "SERFC",
    "WGRFC"
]


def turn_off_indeterminate():
    indeterminate.name = "Download Complete"
    indeterminate.active = False
    indeterminate.visible = False
    return


def turn_on_indeterminate():
    indeterminate.name = "Downloading..."
    indeterminate.visible = True
    indeterminate.active = True
    return


def on_geojson_click(event, feature, **kwargs):
    rfc_selector.value = feature['properties']["BASIN_ID"]


def get_marker_and_map():
    center = (MAP_CENTER_X, MAP_CENTER_Y)
    lmap = Map(center=center, zoom=4, height=500)
    lmap.add(geojson_layer)
    lmap.layout.height = "100%"
    lmap.layout.width = "100%"
    return lmap


def download_historical_data(event) -> None:
    """Download historical data for selected RFC."""
    fews_download_dir = Path(download_dir_text.value)
    if not fews_download_dir.exists():
        raise ValueError(
            f"The directory: {fews_download_dir}, "
            "does not exist. Please create it first!"
        )

    logger.info(f"Downloading historical data to {fews_download_dir.as_posix()}...")
    s3_download_directory_cli(
        prefix=f"{rfc_selector.value}/historicalData",
        local=Path(
            fews_download_dir,
            f"{rfc_selector.value}/cardfiles"
        ).as_posix()
    )
    logger.info("Data download complete.")


def install_fews_standalone_pf(event) -> None:
    """Download standalone configuration from S3 to the working directory."""
    turn_on_indeterminate()
    install_fews_standalone(download_dir_text.value, rfc_selector.value)
    turn_off_indeterminate()
    return


# MAP (ipyleaflet)
with open(RFC_BOUNDARIES) as f:
    geojson_data = json.load(f)

geojson_layer = GeoJSON(
    data=geojson_data,
    hover_style={
        'color': 'red', 'dashArray': '0', 'fillOpacity': 0.6
    },
)
lmap = get_marker_and_map()
geojson_layer.on_click(on_geojson_click)

# WIDGETS
rfc_selector = pn.widgets.Select(name="", options=RFC_IDS, value=RFC_IDS[5])

download_dir_text = pn.widgets.TextInput(
    name='Directory to download the data:',
    value='/home/jovyan'
)

logger_filepath = Path(download_dir_text.value, "dashboard2.log")
print(f"Logging to: {logger_filepath}")
logger = set_up_logger(logger_filepath)

download_configs_button = pn.widgets.Button(
    name='Download Configs',
    button_type='primary'
)
download_configs_button.on_click(install_fews_standalone_pf)

download_data_button = pn.widgets.Button(
    name='Download Data',
    button_type='primary'
)
download_data_button.on_click(download_historical_data)

indeterminate = pn.indicators.Progress(
    name='Indeterminate Progress',
    active=False,
    visible=False,
    styles={"height": "15px"},
)

# LAYOUT
download_row = pn.Row(
    rfc_selector,
    download_configs_button,
    download_data_button
)

column = pn.Column(
    pn.pane.IPyWidget(lmap, sizing_mode="stretch_both", min_height=500),
    download_row,
    pn.Row(download_dir_text),
    pn.Row(indeterminate)
)

logo_path = Path(__file__).parent / "images" / "CIROHLogo_200x200.png"
template = pn.template.FastListTemplate(
    site="HEFS-FEWS",
    title="Exploration System Dashboard",
    logo=str(logo_path),
    header_background=ACCENT_BASE_COLOR,
    accent_base_color=ACCENT_BASE_COLOR,
    main=[column],
).servable()
