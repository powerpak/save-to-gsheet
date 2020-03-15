# Save To GSheet

A small Sinatra app that accepts HTTP POST requests from web forms and saves them to Google Spreadsheets.

This only provides the backend, not the frontend for such forms. This form responds in JSON, so it is best suited for form data submitted using `XMLHTTPRequest` or the [Fetch API](https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API).

Form submissions can be protected with [reCAPTCHA](https://www.google.com/recaptcha/) to discourage automated submissions.

To get started with this app, `git clone` it to a directory, run `bundle install`, and then `cp config.dist.yaml config.yaml` and customize that configuration appropriately. The included example config is for a contact form I used on my wedding website :-)

The below sections explain how to appropriately configure Google Spreadsheet credentials, CORS, and reCAPTCHA in your own `config.yaml`. To try out your settings, run `rackup` to serve the app locally (by default, from <http://localhost:9393>). To serve it in production, use any reputable online guide for Sinatra deployment under Nginx or Apache, such as [this one](https://www.digitalocean.com/community/tutorials/how-to-deploy-sinatra-based-ruby-web-applications-on-ubuntu-13).

## Setting up Google credentials

In order to save data to a Google Spreadsheet, this app needs credentials created in the Google APIs Console.

1. Go to the [Google APIs Console](https://console.developers.google.com/).
2. Create a new project.
3. Click Enable API. Search for and enable the Google Drive API.
4. Create credentials for a Web Server to access Application Data.
5. Name the service account and grant it a Project Role of Editor.
6. Download the JSON file.
7. Copy the JSON file to this directory and rename it to `client_secret.json`.

You'll then need to grant access to a Google Spreadsheet for this service account. To do this, open `client_secret.json` and find and copy the `client_email`. In your spreadsheet, click the “Share” button in the top right and paste the email. This will give your service account edit rights.

Then, get the spreadsheet key from the URL (it's the long gnarly part after `spreadsheets/d/` and before `/edit`) and put this in your `config.yaml` under `spreadsheet_key`. You'll want to also set `worksheet` to the index of the worksheet (i.e. tab) where data will be appended, which starts from `0` for a spreadsheet with a single worksheet.

## Setting up cross-domain requests

You may choose to serve this Sinatra app from a different domain than your primary website that will host the HTML and frontend for the forms submitting to it. That's completely OK, but if so you'll need to tell this app about those domains so that it can serve the appropriate [CORS headers](https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS).

List all the domains that will submit data to this app under the `allowed_origins` section of `config.yaml`.

## Setting up reCAPTCHA

Go to the [reCAPTCHA website](https://www.google.com/recaptcha/admin/create) and register a new website there. You will need to provide the domains of the websites that will be hosting the form presented to end users. You won't need to include the domain that hosts this Sinatra app.

You will be given a site key, and a secret key.

- The site key will be needed for the HTML code that serves the form presented to users. 
- The secret key should be copied to the `recaptcha_secret` part of `config.yaml`.

## Sample code for the frontend

A minimal example of how to create a frontend that submits data to this backend is in `EXAMPLE-frontend.html`, which the app also will serve at `/example` when it is not run in a production environment.
