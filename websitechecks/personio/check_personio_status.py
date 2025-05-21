#!/usr/bin/env python3

# Created by Check_MK Agent Bakery.
# This file is managed via WATO, do not edit manually or you
# lose your changes next time when you update the agent.

# Version 0.5 - Manuel Michalski
# Website: www.47k.de
# Datum: 21.05.2025
# Beschreibung: Prüft Personio-Status und verweist bei Fehlern auf die Webseite

import requests
from bs4 import BeautifulSoup

### Konfiguration ###
URL = "https://status.personio.de"

SERVICES = {
    "System availability": "System availability",
    "Personio Conversations": "Personio Conversations",
    "Email services": "Email services",
    # Exakter Name inklusive "(API)"
    "First and third-party integrations (API)": "First and third-party integrations (API)",
    "Support applications (Help & Feedback)": "Support applications (Help & Feedback)",
    "Personio Payroll DE": "Personio Payroll DE"
}

### Funktionen ###
def check_status():
    try:
        response = requests.get(URL)
        response.raise_for_status()
    except requests.RequestException as e:
        print(f"2 'Personio Status' - Fehler beim Abrufen der Statusseite: {e} | Siehe {URL} für weitere Details")
        return {}

    try:
        soup = BeautifulSoup(response.content, 'html.parser')
        service_status = {}

        components = soup.find_all("div", class_="component-container")
        for component in components:
            name_tag = component.find("span", class_="name")
            status_tag = component.find("span", class_="component-status")
            if not name_tag or not status_tag:
                continue

            name = name_tag.get_text(strip=True)
            status = status_tag.get_text(strip=True)

            if name in SERVICES.values():
                service_status[name] = status

        return service_status
    except Exception as e:
        print(f"2 'Personio Status' - Fehler beim Parsen der Statusseite: {e} | Siehe {URL} für weitere Details")
        return {}


def main():
    service_status = check_status()

    non_operational = []
    details = []

    for key, display in SERVICES.items():
        status = service_status.get(display, "Unbekannt")
        if status.lower().strip() != "operational":
            non_operational.append(display)
        details.append(f"{display} ist {status.lower()}")

    if non_operational:
        summary = f"{len(non_operational)} Service(s) nicht operational: {', '.join(non_operational)}"
        code = 2
    else:
        summary = "Alle Systeme sind operational"
        code = 0

    details_output = "\\n".join(details)
    # Ausgabe wie zuvor mit literal '\n' und Link
    print(f"{code} 'Personio Status' - {summary} | Siehe {URL} für weitere Details \\n{details_output}")


if __name__ == "__main__":
    main()
