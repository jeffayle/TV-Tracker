#!/usr/bin/env ruby1.9
require 'sinatra'
require 'erb'
require 'rack-datamapper-session'
require 'rack-flash'
require 'dm-core'
require 'dm-timestamps'
require 'dm-types'

#DataMapper classes
DataMapper.setup(:default,ENV['DATABASE_URL']||"sqlite3://#{Dir.pwd}/db.sqlite")

class User
    include DataMapper::Resource
    property :id, Serial
    property :name, String, :length=>100
    property :created_at, DateTime
    property :password, BCryptHash

    has n, :tvShows
end

class TvShow
    include DataMapper::Resource
    property :id, Serial
    property :name, String, :length=>100
    property :created_at, DateTime
    property :updated_at, DateTime
    property :season, Integer
    property :episode, Integer

    belongs_to :user
end

DataMapper.auto_upgrade!

#Rack
use Rack::Session::DataMapper
use Rack::Flash, :accessorize=>[:notice]

#Sinatra stuffs
before do
    #Retrieve user from the database
    session[:user] = User.get session[:user] if session[:user]
end

after do
    #Store user
    session[:user] = session[:user].id if session[:user]
end

get '/' do
    if session[:user]
        redirect '/user'
    else
        erb :home
    end
end

post '/signup' do
    username = params[:username]
    passwordA = params[:passwordA]
    passwordB = params[:passwordB]

    if username=="" or passwordA=="" or passwordB==""
        flash[:notice] = 'Please fill out all fields.'
        redirect '/'
    elsif passwordA != passwordB
        flash[:notice] = 'Passwords do not match.'
        redirect '/'
    elsif User.first(:name=>username)
        flash[:notice] = 'Username already taken.'
        redirect '/'
    else
        u = User.new
        u.name = username
        u.password = passwordA
        u.save

        flash[:notice] = 'User successfully created.'
        redirect '/'
    end
end

post '/login' do
    username = params[:username]
    password = params[:password]
    u = User.first :name=>username

    if u and u.password==password
        session[:user] = u
        flash[:notice] = 'Login successful.'
    else
        flash[:notice] = 'Username not found or password incorrect.'
    end

    redirect '/'
end

get '/user' do
    @shows = TvShow.all :user=>session[:user], :order=>:updated_at.desc
    erb :user
end

post '/addshow' do
    show = params[:show]
    season = params[:season].to_i || 1
    episode = params[:episode].to_i || 1

    tv = TvShow.new
    tv.user = session[:user]
    tv.name = show
    tv.season = season
    tv.episode = episode
    tv.save

    flash[:notice] = 'TV show added.'
    redirect '/user'
end

get '/nextep/:id' do |id|
    show = TvShow.get id
    show.episode += 1
    show.save

    redirect '/user'
end

get '/nextseason/:id' do |id|
    show = TvShow.get id
    show.season += 1
    show.episode = 1
    show.save

    redirect '/user'
end

get '/edit/:id' do |id|
    @show = TvShow.get id
    erb :edit
end

post '/edit' do
    id = params[:id]
    name = params[:show]
    season = params[:season].to_i || 1
    episode = params[:episode].to_i || 1

    show = TvShow.get id
    show.name = name
    show.season = season
    show.episode = episode
    show.save

    redirect '/user'
end

get '/delete/:id' do |id|
    show = TvShow.get id
    show.destroy!
    redirect '/user'
end

get '/logout' do
    session[:user] = nil
    redirect '/'
end
