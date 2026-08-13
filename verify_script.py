from playwright.sync_api import sync_playwright
import time

def main():
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page(viewport={"width": 1280, "height": 800})

        page.on("console", lambda msg: print(f"CONSOLE: [{msg.type}] {msg.text}"))
        page.on("pageerror", lambda err: print(f"PAGE ERROR: {err}"))
        page.on("requestfailed", lambda req: print(f"REQUEST FAILED: {req.url} ({req.failure.error_text if req.failure else 'No error text'})"))

        print("Navigating to http://localhost:3000 ...")
        page.goto("http://localhost:3000")

        print("Waiting 10 seconds...")
        time.sleep(10)

        page.screenshot(path="verification_screenshot.png")
        print("Screenshot saved to verification_screenshot.png")

        browser.close()

if __name__ == "__main__":
    main()
