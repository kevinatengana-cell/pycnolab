from playwright.sync_api import sync_playwright
import time

def main():
    with sync_playwright() as p:
        print("Launching browser...")
        browser = p.chromium.launch(headless=True)
        page = browser.new_page(viewport={"width": 1440, "height": 1080})

        print("Navigating to http://localhost:3000 ...")
        page.goto("http://localhost:3000")

        print("Waiting 10 seconds for Flutter Web to boot...")
        time.sleep(10)

        # Click on center of the screen to focus and send PageDown keys
        print("Focusing and pressing PageDown to scroll...")
        page.mouse.click(720, 500)
        for i in range(5):
            page.keyboard.press("PageDown")
            time.sleep(0.5)

        time.sleep(2)

        # Take a screenshot of home screen with preloaded lots
        print("Saving homepage_with_lots.png...")
        page.screenshot(path="homepage_with_lots.png")

        # The Compare button is at the bottom right. Now that we have scrolled down,
        # it is visible on screen. Let's try to click on the button using coordinate click.
        # Since it's in the lower portion of the viewport now, let's try (1150, 920) or (1150, 850)
        # Let's try a couple of coordinates to be sure, or try locating by text.
        print("Clicking Comparer les lots button...")
        try:
            # Let's try text locator or click on the button's location.
            compare_button = page.get_by_text("Comparer les lots")
            if compare_button.count() > 0:
                print("Found compare button by text, clicking...")
                compare_button.first.click()
            else:
                print("Clicking by coordinate (1150, 850)...")
                page.mouse.click(1150, 850)
        except Exception as e:
            print(f"Click failed: {e}")

        time.sleep(5)
        print("Saving comparison_screen.png...")
        page.screenshot(path="comparison_screen.png")

        browser.close()
        print("Flow completed successfully!")

if __name__ == "__main__":
    main()
