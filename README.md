# mitm_test_proxy

## status

In progress.  To be ready to replace puffing-billy we need:

- [x] test the most recent release of puffing-billy/em doesn't fix the bug
(yes it still does)
- [x] handle requests to http sites
- [x] use list of string, string pairs to replace the response for http
- [ ] use list of regex, proc pairs to rewrite requests for http
- [ ] use list of regex, proc pairs to rewrite requests for https
  - [x] handle CONNECT requests
  - [x] create self signed certificates on demand
  - [x] trigger creation on TLS handshake
  - [x] parse http request and pass to rack-proxy
- [ ] return request to hosts not on the allowlist as empty html bodies

## What is this?

This allows you to run a Man-In-The-Middle proxy that you will configure a
test browser (perhaps with Capybara) to use.  You will be able to modify
responses from 3rd parties and assert that requests where made.

```ruby
# all requests not on allowlist or stubbed will return with an
# empty body
mitm_test_proxy = MitmTestProxy.new
# intercept a request to a specific url and return what we want
mitm_test_proxy.stub('http://www.google.com/').and_return(text: "I'm not Google!")
# allow requests to be proxied
mitm_test_proxy.allowlist << 'www.example.com'

# start it in another thread, will block until it's running
mitm_test_proxy.start

# later after test

# shutdown the server thread, will block until the thread is done
mitm_test_proxy.shutdown
```

This gem is based on puma.

## Alternatives that where considered

There are other ruby libraries that have the same purpose as this.

### [puffing-billy](https://github.com/oesmith/puffing-billy)

What BidWrangler currently uses.  Works great in Ruby 2.7 and Puma 4.  Has a bug where it sends two Content-Length headers which will not work with Puma 6.  Is built on EventMachine, which sadly seems to be dead.  While using it we've seen segfaults when stubbing some sites which has stopped us from testing what we wanted to.  Has had a recent release, which has not be tested to see if it fixes the bug (but it's unlikely).

Puma changes that disallow multiple Content-Length:

- <https://github.com/puma/puma/commit/5bb7d202e24dec00a898dca4aa11db391d7787a5>
- <https://github.com/advisories/GHSA-h99w-9q5r-gjq9>

### [ritm](https://github.com/argos83/ritm)

Have not tried it.  Appears to be dead.  Built on an old version of WEBrick, which has changed in later versions.

### [evil-proxy](https://github.com/bbtfr/evil-proxy)

Have not tried it.  Appears to be dead. Built on an old version of WEBrick, which has changed in later versions.

## notes

- maybe use WEBrick and get full hijack with this: <https://projects.theforeman.org/issues/26958>
- <https://mitmproxy.org/> could we use python?
- <https://gist.github.com/xaviershay/1470160>
- <https://www.johnnunemaker.com/ruby-rack-background-thread/>
- <https://stackoverflow.com/questions/13476639/ruby-mitm-proxy>
