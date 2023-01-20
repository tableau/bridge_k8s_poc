import urllib.request

import dotenv
import json
import logging
import requests
import os

from http.client import responses


def use_token(url, site_name, token_name, token_value):
    body = {
        "credentials": {
            "personalAccessTokenName": token_name,
            "personalAccessTokenSecret": token_value,
            "site": {
                "contentUrl": site_name
            }
        }
    }
    urllib.request.urlopen()
    r = requests.post(f"{url}/api/3.18/auth/signin", json=body)
    status_text = f"{r.status_code} {responses[r.status_code]}"
    if r.status_code != 200:
        logging.error({"token_name": token_name, "status": status_text})
    else:
        logging.info({"token_name": token_name, "status": status_text})


def main():
    dotenv.load_dotenv("config/.env")
    logging.basicConfig(
        format="%(asctime)s %(levelname)-8s %(module)-10s %(message)s",
        level=os.getenv("LOGLEVEL", "WARNING"))
    url = os.getenv("SERVERPOD")
    site_name = os.getenv("SITE")
    with open("secret/pat.json") as f:
        d: dict = json.load(f)
    logging.info({
        "url": url,
        "site_name": site_name,
        "tokens": len(d)
    })
    logging.info("testing the tokens")
    for token_name, token_value in d.items():
        use_token(url, site_name, token_name, token_value)


if __name__ == '__main__':
    main()
