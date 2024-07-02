#!/usr/bin/env python3

# Created by Check_MK Agent Bakery.
# This file is managed via WATO, do not edit manually or you
# lose your changes next time when you update the agent.

# Version 0.2 - Manuel Michalski / www.47k.de
# Datum: 19.06.2024
# Description: Check Personio Status
# Prerequisites: pip3 install requests beautifulsoup4

import requests
from bs4 import BeautifulSoup

### Debug ###
#import logging

## Setup logging ##
#logging.basicConfig(level=logging.DEBUG, format='%(asctime)s - %(levelname)s - %(message)s')
############

URL = "https://status.personio.de/"

SERVICES = {
    "System availability": "System availability",
    "Personio Conversations": "Personio Conversations",
    "Email services": "Email services",
    "First and third-party integrations": "First and third-party integrations",
    "Support applications (Find Answers)": "Support applications (Find Answers)",
    "API": "API"
}

def check_status():
    try:
        response = requests.get(URL)
        response.raise_for_status()  # Raise HTTPError for bad responses
    except requests.RequestException as e:
        logging.error(f"Fehler beim Abrufen der Statusseite: {e}")
        return {}

    try:
        soup = BeautifulSoup(response.content, 'html.parser')
        service_status = {}

        components = soup.find_all("div", class_="component-inner-container")
        for component in components:
            service_name = component.find("span", class_="name").get_text(strip=True)
            service_status_text = component.find("span", class_="component-status").get_text(strip=True)
            if service_name in SERVICES.values():
                service_status[service_name] = service_status_text

        return service_status
    except Exception as e:
        logging.error(f"Fehler beim Parsen der Statusseite: {e}")
        return {}

def main():
    service_status = check_status()

    non_operational_services = []
    details = []

    for service_key, service_value in SERVICES.items():
        status = service_status.get(service_value, "Unbekannt")
        if status != "Operational":
            non_operational_services.append(service_value)
            details.append(f"{service_value} ist {status.lower()}")
        else:
            details.append(f"{service_value} ist operational")

    if non_operational_services:
        summary = f"{len(non_operational_services)} Service(s) nicht operational: {', '.join(non_operational_services)}"
        status_code = 2
    else:
        summary = "Alle Dienste sind operational"
        status_code = 0

    details_output = "\\n".join([f"{detail}" for detail in details])
    print(f"{status_code} 'Personio Status' - {summary} \\n{details_output}")

if __name__ == "__main__":
    main()
