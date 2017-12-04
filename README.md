# Rack::Kibo

A Rack Middleware to present structured JSON responses

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rack-kibo'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install rack-kibo

## What Kibo Does

Kibo will wrap any request for JSON, or response containing the JSON
Content-Type `application/json` in a simple structured JSON object:

```javascript
{
  "success": true,
  "responded_at": 'utc date of response',
  "version": 1,
  "location": "/location/of/resource/requested",
  "body": {
    // your server's response object
  }
}
```

Kibo will always return a successful HTTP Status code (anything less
than 400) unless there was an error within Kibo itself. If the response
from your server is an error code, Kibo returns HTTP 200, with the `success` 
property of `false`


## Getting Started

### Rackup-based apps

Add the middleware to your Rack app



```ruby
require 'rack/kibo'

use Rack::Kibo
```

### Options

You can control how Kibo returns errors by supplying an `:expose_errors`
item in the initialization of your middleware

```ruby
use Rack::Kibo, :expose_errors => true
```

`:expose_errors` defaults to `false`

Setting this value to `true` will return exception messages back to the
browser, potentially exposing your API's implementation. In addition to
exposing the error message, the original server response will be
returned.

### API Version Computation

Kibo looks for request path segments that contain `api/{version}` where
`version` is a number, or a number preceeded by either a lowercase `v`
or uppercase 'V'

```ruby
"/some/api/1/order/get"
=> 1

"/some/api/v2/order/get"
=> 2

"/api/V3/order/get"
=> 3
```

Kibo works for any request path, but will return a version of `0` if it
does not find version information from the request path

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## TODO

- [ ] Optionally allow servers response code to be returned by Kibo
instead of returning 200 for errors
- [ ] Optionally allow additional `Content-Type`'s to trigger Kibo
response wrapping (ex: `application/vnd+customJSON`)

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/marshallmick007/rack-kibo.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

