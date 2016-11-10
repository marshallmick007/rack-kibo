require 'spec_helper'

describe Rack::Kibo do
  let(:app) { ->(env) { [ 200, env, [ response ] ]} }

  let(:middleware) do
    Rack::Kibo.new(app, {:expose_errors => true})
  end

  let(:expected_keys) { [ "success", "body", "location", "version", "responded_at" ] }

  def env_for(url, opts={})
    Rack::MockRequest.env_for(url, opts)
  end

  def json_response_env(env)
    env["Content-Type"] = "application/json"
    env
  end
  
  it 'has a version number' do
    expect(Rack::Kibo::VERSION).not_to be nil
  end

  context 'with json response' do
    let(:response) { { :data => 1, :arr => ["a", "b", "c" ] }.to_json }

    it 'returns data as-is when no Content-Type is specified' do
      code, env, rsp = middleware.call env_for('http://test.tld/junk')
      expect(code).to be(200)
      expect(rsp[0]).to be(response)
    end

    it 'returns data wrapped when request JSON Content-Type is specified' do
      env_rq_json = env_for('http://test.tld/garbage/api/V1234/test', {"HTTP_ACCEPT" => "application/json"} )
      code, env, rsp = middleware.call env_rq_json
      data = JSON.parse(rsp[0])
      expect(code).to be(200)
      expect(data.keys).to match_array(expected_keys)
      expect(data["body"]).to eq(JSON.parse(response))
    end
  end

  context "supports additional web server env properties" do
    let(:response) { { :data => 1, :arr => ["a", "b", "c" ] }.to_json }

    it 'supports env "REQUEST_PATH" property if present' do
      env1 = env_for("http://test.tld/junk", { "Content-Type" => "application/json"})
      env1["REQUEST_PATH"] = "/some/other/path"
      code, env, rsp = middleware.call env1
      data = JSON.parse(rsp[0])
      expect(data["location"]).to eq("/some/other/path")
    end
  end

  context 'with server-supplied JSON Content-Type' do
    let(:response) { { :data => 1, :arr => ["a", "b", "c" ] }.to_json }
    let(:app) { ->(env) { [ 200, json_response_env(env), [ response ] ]} }

    it 'returns data wrapped when response JSON Content-Type is specified' do
      code, env, rsp = middleware.call env_for('http://test.tld/junk')
      data = JSON.parse(rsp[0])
      expect(code).to be(200)
      expect(data.keys).to match_array(expected_keys)
      expect(data["body"]).to eq(JSON.parse(response))
    end

    it 'computes api version from request url with a "api/{digit}"' do
      code, env, rsp = middleware.call env_for('http://test.tld/api/1/test')
      data = JSON.parse(rsp[0])
      expect(data["version"]).to eq(1)
    end

    it 'computes api version from request url with a "api/{digits}"' do
      code, env, rsp = middleware.call env_for('http://test.tld/api/12/test')
      data = JSON.parse(rsp[0])
      expect(data["version"]).to eq(12)
    end

    it 'computes api version from request url with a "/garpage/api/{digits}"' do
      code, env, rsp = middleware.call env_for('http://test.tld/garbage/api/12/test')
      data = JSON.parse(rsp[0])
      expect(data["version"]).to eq(12)
    end

    it 'computes api version from request url with a lowercase "v" in the path' do
      code, env, rsp = middleware.call env_for('http://test.tld/garbage/api/v123/test')
      data = JSON.parse(rsp[0])
      expect(data["version"]).to eq(123)
    end

    it 'computes api version from request url with a uppercase "V" in the path' do
      code, env, rsp = middleware.call env_for('http://test.tld/garbage/api/V1234/test')
      data = JSON.parse(rsp[0])
      expect(data["version"]).to eq(1234)
    end

    it 'echoes the request path in the "location" property' do
      code, env, rsp = middleware.call env_for('http://test.tld/garbage/api/V1234/test')
      data = JSON.parse(rsp[0])
      expect(data["location"]).to eq("/garbage/api/V1234/test")
    end
  end

  context 'Handle Errors' do
    context 'server returns error status codes' do
      let(:response) { { :data => 1, :arr => ["a", "b", "c" ] }.to_json }
      let(:app) { ->(env) { [ 500, json_response_env(env), [ response ] ]} }

      it 'wraps status codes when server returns JSON' do
        code, env, rsp = middleware.call env_for('http://test.tld/garbage/api/V1234/test')
        data = JSON.parse(rsp[0])
        #middleware wraps error codes and returns 200
        expect(code).to eq(200)
        expect(data["success"]).to be(false)
        expect(data["body"]).to eq(JSON.parse(response))
      end

      it 'returns original JSON data in body' do
        code, env, rsp = middleware.call env_for('http://test.tld/garbage/api/V1234/test')
        data = JSON.parse(rsp[0])
        expect(data["body"]).to eq(JSON.parse(response))
      end
    end

    context 'server throws exception, using expose_errors' do
      let(:response) { { :data => 1, :arr => ["a", "b", "c" ] }.to_json }
      let(:app) { ->(env) { raise StandardError.new("Test Error") } }

      it 'returns 500 when not expecting JSON' do
        code, env, rsp = middleware.call env_for('http://test.tld/garbage/api/V1234/test')
        #middleware wraps error codes and returns 200
        expect(code).to eq(500)
      end

      it 'wrap status codes when JSON is expected' do
        env_rq_json = env_for('http://test.tld/garbage/api/V1234/test', {"HTTP_ACCEPT" => "application/json"} )
        code, env, rsp = middleware.call env_rq_json
        data = JSON.parse(rsp[0])
        expect(code).to eq(200)
        expect(data["success"]).to be(false)
        expect(data["body"]["error"]["message"]).to eq("Test Error")
      end

    end

    context 'mismatched content-negotiation' do
      let(:app) { ->(env) { [200, env, [ 'test' ] ] } }

      it 'wrap proper data in error' do
        env_rq_json = env_for('http://test.tld/garbage/api/V1234/test', {"HTTP_ACCEPT" => "application/json"} )
        code, env, rsp = middleware.call env_rq_json
        data = JSON.parse(rsp[0])
        expect(code).to eq(200)
        expect(data["success"]).to be(false)
        expect(data["body"]["error"]["data"]).to eq(['test'])
      end

      it 'return existing data when no content-negotiation mismatch' do
        env_rq_json = env_for('http://test.tld/garbage/api/V1234/test')
        code, env, rsp = middleware.call env_rq_json
        expect(code).to eq(200)
        expect(rsp).to eq(['test'])
      end

    end

    context 'server throws exception, without expose_errors' do
      let(:response) { { :data => 1, :arr => ["a", "b", "c" ] }.to_json }
      let(:app) { ->(env) { raise StandardError.new("Test Error") } }
      let(:middleware) do
        Rack::Kibo.new(app, {:expose_errors => false})
      end

      it 'returns 500 when not expecting JSON' do
        code, env, rsp = middleware.call env_for('http://test.tld/garbage/api/V1234/test')
        #middleware wraps error codes and returns 200
        expect(code).to eq(500)
      end

      it 'wrap status codes when JSON is expected' do
        env_rq_json = env_for('http://test.tld/garbage/api/V1234/test', {"HTTP_ACCEPT" => "application/json"} )
        code, env, rsp = middleware.call env_rq_json
        data = JSON.parse(rsp[0])
        expect(code).to eq(200)
        expect(data["success"]).to be(false)
        expect(data["body"]["error"]["message"]).to eq('Error')
      end

    end

    context 'server not returning JSON content type' do
      let(:response) { { :data => 1, :arr => ["a", "b", "c" ] }.to_json }
      let(:app) { ->(env) { [ 500, env, [ response ] ]} }

      it 'does not wrap status codes when JSON is not expected' do
        code, env, rsp = middleware.call env_for('http://test.tld/garbage/api/V1234/test')
        data = JSON.parse(rsp[0])
        expect(code).to eq(500)
        # should get original, non-wrapped response
        expect(rsp[0]).to eq(response)
      end
    end
  end
end
