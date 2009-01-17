require 'test_helper'
require 'action_controller'

class MyRackApp
  def call(env)
    status, headers, response = @app.call(env)
    response.body.gsub!(/This/, "THIS")
    response.to_a
  end
end

class OtherRackApp
  def call(env)
    status, headers, response = @app.call(env)
    response.to_a
  end
end

class StatusChanger
  def call(env)
    status, headers, response = @app.call(env)
    if response.body =~ /SECRET/
      response.status = "404 Not Found"
    end
    response.to_a
  end
end

class MyIndexApp
  def call(env)
    status, headers, response = @app.call(env)
    response.body.gsub!(/Dave/, "David")
    response.to_a
  end
end

class MyNoShowApp
  def call(env)
    status, headers, response = @app.call(env)
    response.body.gsub!(/s/, "S")
    response.to_a
  end
end

class ApplicationController < ActionController::Base
end

class ThingsController < ApplicationController
  middle MyRackApp
  middle MyIndexApp, :only => "index"
  middle MyNoShowApp, :except => ["show", "index"]
  middle StatusChanger, :only => "change_status"

  def index
    render :text => "Dave is cool, isn't Dave?"
  end
  def show
    render :text => "This is an item or something, Dave."
  end
  def special
    render :text => "This is so special."
  end
  def change_status
    render :text => "Status should be 404 because this is SECRET."
  end
end

ActionController::Routing::Routes.draw do |map|
  map.connect 'things/index',
    :controller => "things"
  map.connect 'things/show/:id',
    :controller => "things", :action => "show"
  map.connect 'things/special',
    :controller => "things", :action => "special"
  map.connect 'things/change_status',
      :controller => "things", :action => "change_status"
end

class PerActionMwTest < ActionController::IntegrationTest
  def test_gsub_on_body_and_show_does_not_do_index_app
    get("things/show/1")
    assert_equal("THIS is an item or something, Dave.", response.body)
    assert_equal("200 OK", response.status)
  end

  def test_index_app
    get("things/index")
    assert_equal("David is cool, isn't David?", response.body)
    assert_equal("200 OK", response.status)
  end

  def test_except_show_and_index
    get("things/special")
    assert_equal("ThiS iS So Special.", response.body)
    assert_equal("200 OK", response.status)
  end

  def test_status_changer
    get("things/status_changer")
    assert_equal("404 Not Found", response.status)
  end
end
