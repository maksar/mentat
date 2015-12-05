require 'simplecov'
SimpleCov.start

require 'rspec'

require_relative 'user'

VOTE = Permission::VOTE
FORCE = Permission::FORCE
NONE = Permission::NONE
ALL = Permission::ALL
ACTIONABLE = Permission::ACTIONABLE
