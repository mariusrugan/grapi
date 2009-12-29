require 'curl'

module Grapi

  class Reader

    def initialize(verbose= false)
      @client = ::Curl::Easy.new do | easy |
        easy.headers= {
          "User-Agent"      => "Grapi::Reader /0.2 +gzip",
          "Accept-Encoding" => "gzip, deflate",
          "GData-Version"   => 2
        }
        easy.follow_location= true
        easy.verbose= true if verbose
      end
      @token = nil
    end

    def get(url)
      make_request(url){|c| c.http_get }
    end

    def post(url, params)
      curl_post_params= params.inject([]){|p, e| p << ::Curl::PostField.content(e[0],e[1])}
      make_request(url){|c| c.http_post(*curl_post_params)}
    end

    def post_with_token(url, params)
      request_token if @token.nil?
      params["T"]= @token
      post url, params
    end

    def login(username, password)
      post "https://www.google.com/accounts/ClientLogin", {
        "Email" => username,
        "Passwd" => password,
        "source" => @client.headers["User-Agent"],
        "service" => "reader",
        "accountType" => "HOSTED_OR_GOOGLE"
      }
      @client.body_str.uncompress =~ /^SID=(.*)\n/
      @client.headers['Cookie']= "SID=#{$1}"
      self
    end

    def unsubscribe(feed_url)
      edit_subscription "feed/#{feed_url}", "unsubscribe"
    end

    def subscribe(feed_url, label= "test")
      edit_subscription "feed/#{feed_url}", "subscribe", {"a" => "user/-/label/#{label}"}
    end

    def mark_as_read(entry_id)
      post_with_token "http://www.google.com/reader/api/0/edit-tag", {"i" => entry_id, "a" => "user/-/state/com.google/read"}
    end

    def reading_list(continuation= nil, dump_data= false)
      get "http://www.google.com/reader/atom/user/-/state/com.google/reading-list?xt=user/-/state/com.google/read&ck=#{Time.now.to_i*1000}&n=1000&c=#{continuation}"
      response= @client.body_str.uncompress
      File.open("/tmp/#{Time.now.to_i}-reading_list.atom", "w"){|f|f<<response} if dump_data
      response
    end

    private

      def edit_subscription(feed_url, action, params={})
        post_with_token "http://www.google.com/reader/api/0/subscription/edit", { "s" => "feed/#{feed_url}", "ac" => action }.update(params)
        response = @client.body_str.uncompress
        unless response == "OK"
          $stderr<< "WARN: [#{__FILE__}:#{__LINE__}] ~> response is not OK. probably token has expired!\n#{response}\n\n"
        end
      end

      def request_token
        get "http://www.google.com/reader/api/0/token"
        @token = @client.body_str.uncompress
      end

      def make_request(url)
        @client.url= url
        yield @client
        @client.perform
        self
      end
  end
end