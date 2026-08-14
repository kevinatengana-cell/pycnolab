from playwright.sync_api import sync_playwright
import time

def main():
    with sync_playwright() as p:
        print("Launching browser...")
        browser = p.chromium.launch(headless=True)
        page = browser.new_page(viewport={"width": 1440, "height": 1400}) # Slightly taller to see charts

        print("Navigating to http://localhost:3000 ...")
        page.goto("http://localhost:3000")

        print("Waiting 12 seconds for Flutter Web to load CompareScreen...")
        time.sleep(12)

        print("Saving comparison_view_top.png...")
        page.screenshot(path="comparison_view_top.png")

        # We can also capture a bottom screenshot if we scroll a bit
        print("Focusing and pressing PageDown to scroll...")
        page.mouse.click(720, 500)
        page.keyboard.press("PageDown")
        time.sleep(2)

        print("Saving comparison_view_bottom.png...")
        page.screenshot(path="comparison_view_bottom.png")

        browser.close()
        print("Flow completed successfully!")

if __name__ == "__main__":
    main()
