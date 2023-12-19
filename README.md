# mitm_test_proxy

## status

In progress.  Doesn't do anything useful yet.

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

## Alternatives that where considered

There are other ruby libraries that have the same purpose as this.

### puffing-billy

Works great in Ruby 2.7 and Puma 4.  Has a bug where it sends two Content-Length headers which will not work with Puma 6.  Is built on EventMachine, which sadly seems to be dead.  While using it we've seen Segfaults when stubbing some sites which has stopped us from testing what we wanted to.
