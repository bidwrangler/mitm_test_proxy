# mitm_test_proxy

## status

Ready to be used.  Works well in at least one Rails app.

## What is this?

This allows you to run a Man-In-The-Middle proxy that you will configure a
test browser (perhaps with Capybara) to use.  You will be able to modify
responses from 3rd parties and assert that requests where made.

Your browser will need to be set to accept self signed TLS certificates.

```ruby
# all requests not on allowlist or stubbed will return with an
# empty body
mitm_test_proxy = MitmTestProxy.new
# intercept a request to a specific url and return what we want:
mitm_test_proxy.stub('http://www.google.com/').and_return(text: "I'm not Google!")
# a stub can be a rack app:
mitm_test_proxy.stub('https://example.com/').and_return(Proc.new {|env| 
  [200, {'content-type' => 'text/plain'}, []]
})

# start it in another thread, will block until it's running
mitm_test_proxy.start

# will start on a random free port, so you'll need to get the port number after it's running
puts mitm_test_proxy.port

# later after test
# shutdown the server thread, will block until the thread is done
mitm_test_proxy.shutdown
```

This gem is based on puma.  Some code for TLS certificate creation was copied from puffing-billy.

To better understand what's happening in side of the proxy, you can set the MITM_TEST_PROXY_LOG_REQUESTS env var.

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
