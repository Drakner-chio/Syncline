"""Renders the banners in banners.html to ../images/syncline-N.jpg (2x)."""
import os, sys
from playwright.sync_api import sync_playwright
here = os.path.dirname(os.path.abspath(__file__))
out = os.path.join(here, "..", "images")
chrome = sys.argv[1] if len(sys.argv) > 1 else None
with sync_playwright() as p:
    browser = p.chromium.launch(executable_path=chrome) if chrome else p.chromium.launch()
    page = browser.new_page(device_scale_factor=2)
    page.goto("file://" + os.path.join(here, "banners.html"))
    page.wait_for_timeout(500)
    for i in range(1, 9):
        png = os.path.join(out, "syncline-%d.png" % i)
        page.locator("#b%d" % i).screenshot(path=png)
    browser.close()
