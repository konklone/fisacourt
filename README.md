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
gem install git twitter pony twilio-rb
```

Copy `config.yml.example` to `config.yml`, then uncomment and fill in any of the sections for `twitter`, `email`, and `twilio` (SMS) to enable those kinds of notifications. They're all optional. Details on enabling each of them are below.

Once configured, run the script to check the FISC website and update `fisa.html`.

```bash
ruby fisa.rb
```

If the site's changed, the new `fisa.html` will be committed to git, and any alert mechanisms you've configured will fire.

#### GitHub integration

To integrate with GitHub, fill out `config.yml`'s `github` section. Set `repo` to `username/repo` (using your real username and repo name, e.g. `konklone/fisa`), and `branch` to the branch you're working on (defaults to `master`).

If you do, two things will happen:

* A `git pull` will be run, from the branch in `config.yml`.
* Your commits will be pushed, to the branch in `config.yml`.
* Notification messages will include a URL to view the change on GitHub, using the repo in `config.yml`.

For this to work, you will need the repo to be configured such that:

* if a `git pull` is run, it will not generate a merge conflict (at HEAD, or can be fast-forwarded)
* there is a remote branch already, and the local branch is set to track it

If the `git push` fails for some reason, it will continue on and alert the world, but not include a Github URL. It will also send an error message via SMS and email to the admin, if they are configured.

If the `git push` succeeds, but the remote branch is not configured correctly, it will post a Github URL to a non-existent commit (a 404). If the branch is then configured correctly and the commits pushed, the URL will then work as expected.

#### Configuring alerts

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

**Pushover**

[Pushover](https://pushover.net/) provides an advanced notification system for Android and iOS. The script can send updates to any of your Pushover devices. As with Twitter, you will need to tell Pushover about your application, but there will not be any delay after registering your applications which are also automatically approved.

```yaml
pushover:
  user_key:
  app_key:
```

To enable Pushover notifications, go to the [Pushover Dashboard](https://pushover.net/), and log in. The dashboard will show your `user_key`.

After that register a new application from the [New Application Page](https://pushover.net/apps/build) by entering the name and brief description of the application. Then you copy the `app_key` field when the registration is complete.

### Todo

* Possibly switch to shell-ing out to the command-line for other git commands instead of the `git` gem, which exhibits strange and uninformative behavior when pushing and pulling
* Allow multiple recipients of SMS and email messages (but mark one as 'admin' for errors)
