# mitm_test_proxy

This allows you to run a Man-In-The-Middle proxy that you will configure a
test browser (perhaps with Capybara) to use.  You will be able to modify
repsonses from 3rd parties and assert that requests where made.

```ruby
mitm_test_proxy = MitmTestProxy.new
mitm_test_proxy.stub('http://www.google.com/').and_return(text: "I'm not Google!")
Thread.new { mitm_test_proxy.start }

# later after test

mitm_test_proxy.stop!
```
