### Watching the Foreign Intelligence Surveillance Court

This project "watches" the public docket of the FISC, and alerts the public and the administrator through tweets, emails, and texts upon any changes.

#### Background

The [Foreign Intelligence Surveillance Court](https://en.wikipedia.org/wiki/United_States_Foreign_Intelligence_Surveillance_Court) (FISC) is responsible, under the law known as [FISA](https://en.wikipedia.org/wiki/Foreign_Intelligence_Surveillance_Act), for overseeing the surveillance activity of the US executive branch.

It has operated since 1978, but had no public docket of orders or opinions until June of 2013. That month, amidst heightened public attention to national surveillance policies, the EFF and the ACLU each filed motions aimed at unsealing FISC records, and successfully requested that these motions themselves become public.

To publish these, the FISC now operates a minimalist public docket that lists links to scanned image PDFs:

> [http://www.uscourts.gov/uscourts/courts/fisc/index.html](http://www.uscourts.gov/uscourts/courts/fisc/index.html)

Since then, several other litigants (Microsoft, Google, and an unnamed "Provider") have filed their own public outstanding motions with FISC. It is expected that future FISC public records will appear at this page.

#### Setup and Usage

Install dependencies:

```bash
bundle install
```

Copy `config.yml.example` to `config.yml`, then uncomment and fill in any of the sections for `twitter`, `email`, and `twilio` (SMS) to enable those kinds of notifications. Details on enabling each of them are below.

Once configured, run the script once to save the current state of the FISC docket (this won't send any alerts):

```bash
bundle exec ruby fisa.rb
```

This will update `./fisa.html` and push it to GitHub, if changed.

Any future executions of `fisa.rb` will check the current state of the FISC docket against the repository, and notify upon changes. If there are changes, you can view them by viewing the diff on GitHub.

#### Configuring services

Turn on different alert methods by uncommenting and filling out sections of `config.yml`.

**Email**

Currently, this project only supports sending emails through SMTP. In the future, it could be extended to support services like Postmark (send in a patch!).

```yaml
email:
  :to:
  :subject:
  :from:
  :via: :smtp
  :via_options:
    :address:
    :port:
    :user_name:
    :password:
    :enable_starttls_auto:
```

Put your email address in the `to` field, and the subject line you want in the `subject field`. The `from` field should be an email address you have permission to send from.

If you have a Gmail account, you have access to their SMTP server, but apparently Google doesn't like to talk about it. The best resources I found for figuring out the values are [here](http://email.about.com/od/accessinggmail/f/Gmail_SMTP_Settings.htm) and [here](http://support.qualityunit.com/107274-How-to-configure-Gmail-SMTP-settings-).

If you use [Pobox](http://pobox.com/) for forwarding (like I do: they're awesome), you can use [their SMTP details](https://www.pobox.com/helpspot/index.php?pg=kb.page&id=118).

**Text messages**

[Twilio](http://www.twilio.com/) is a cheap way to programmatically send text messages (SMS). This project uses Twilio, but there are also excellent alternatives, like [Tropo](https://www.tropo.com/). Both charge a penny, $0.01, for each text message sent (in the US).

```yaml
twilio:
  account_sid:
  auth_token:
  from:
  to:
```

Create a Twilio account, choose a phone number, and copy your Account SID and Auth Token to the `account_sid` and `auth_token` fields. Put your Twilio phone number in the `from` field, and the phone number you wish to receive text messages in the `to` field.


**Twitter**

The script can post to a Twitter account of your choice. You will need to tell Twitter about your application, but there is no delay, as they approve applications automatically (at this time).

```yaml
twitter:
  consumer_key:
  consumer_secret:
  oauth_token:
  oauth_token_secret:
```

To enable posting to Twitter, go to the [Twitter developer portal](https://dev.twitter.com/), and log in **as the account you wish to post from**.

Go to [My Applications](https://dev.twitter.com/apps) and create a new application. You will need to enter a name, description, and website. You do not need to supply a callback URL. Once created, go to the application's Settings tab and change the application's permissions from "Read only" to "Read and Write". Finally, create an access token using the form at the bottom. You may need to refresh the page after a minute to get the access token to show up.

Copy the "Consumer key" and "Consumer secret" to the `consumer_key` and `consumer_secret` fields. Copy the "Access token" and "Access token secret" to the `oauth_token` and `oauth_token_secret` fields.