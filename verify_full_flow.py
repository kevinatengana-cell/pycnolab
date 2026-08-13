from playwright.sync_api import sync_playwright
import time

def main():
    with sync_playwright() as p:
        print("Launching browser...")
        browser = p.chromium.launch(headless=True)
        page = browser.new_page(viewport={"width": 1440, "height": 900})

        print("Navigating to http://localhost:3000 ...")
        page.goto("http://localhost:3000")

        print("Waiting 10 seconds for Flutter Web...")
        time.sleep(10)

        # Click on "Essai de Traction" card at (250, 500)
        print("Clicking Essai de Traction...")
        page.mouse.click(250, 500)
        time.sleep(3)
        page.screenshot(path="config_screen.png")

        # Click on "Passer à l'importation" at (1150, 810) (bottom right of screen)
        print("Clicking Passer à l'importation...")
        page.mouse.click(1150, 810)
        time.sleep(3)
        page.screenshot(path="import_screen.png")

        # Click on browse button at (720, 580) with file chooser expect
        print("Uploading file via coordinate click on browse button...")
        try:
            with page.expect_file_chooser(timeout=5000) as file_chooser_info:
                page.mouse.click(720, 580)
            file_chooser = file_chooser_info.value
            file_chooser.set_files("modele_import_traction.xlsx")
            print("File uploaded successfully!")
        except Exception as e:
            print(f"File upload via file chooser failed or timed out: {e}")
            print("Trying direct input file selection if available...")
            try:
                page.set_input_files("input[type=file]", "modele_import_traction.xlsx")
                print("Direct input file selection succeeded!")
            except Exception as ex:
                print(f"Direct selection failed: {ex}")

        print("Waiting 12 seconds for calculations and results screen to load...")
        time.sleep(12)

        page.screenshot(path="results_general.png")
        print("Results screen general tab screenshot saved.")

        # Click on "Tableau de Données" tab at (720, 100) (middle top)
        print("Clicking Tableau de Données tab...")
        page.mouse.click(720, 100)
        time.sleep(3)
        page.screenshot(path="results_table.png")

        # Click on "Détail par Échantillon" tab at (960, 100)
        print("Clicking Détail par Échantillon tab...")
        page.mouse.click(960, 100)
        time.sleep(3)
        page.screenshot(path="results_details.png")

        browser.close()
        print("Flow completed successfully!")

if __name__ == "__main__":
    main()
