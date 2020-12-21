from altair_saver import save
from selenium import webdriver
from webdriver_manager.chrome import ChromeDriverManager
import os

import ai_research

project_dir = ai_research.project_dir

FIG_PATH = f"{project_dir}/figures"

# Checks if the right paths exist and if not creates them when imported
os.makedirs(f"{FIG_PATH}/png", exist_ok=True)
os.makedirs(f"{FIG_PATH}/html", exist_ok=True)


def google_chrome_driver_setup():
    # Set up the driver to save figures as png
    driver = webdriver.Chrome(ChromeDriverManager().install())
    return driver


def save_altair(fig, name, driver, path=FIG_PATH):
    """Saves an altair figure as png and html
    Args:
        fig: altair chart
        name: name to save the figure
        driver: webdriver
        path: path to save the figure
    """
    print(path)
    save(
        fig,
        f"{path}/png/{name}.png",
        method="selenium",
        webdriver=driver,
        scale_factor=5,
    )
    fig.save(f"{path}/html/{name}.html")


if __name__ == "__main__":
    google_chrome_driver_setup()
