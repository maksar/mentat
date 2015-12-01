require 'set'

class Workflow
  attr_reader :current_step

  def initialize(steps_config)
    @steps_config = steps_config
    @current_step = 0
    @votes = Array.new(steps_config.size) { Set.new }
  end

  def approve(actor)
    return unless actor.active?
    if actor.can_force_step?(@current_step)
      increment
    elsif actor.can_vote_on_step?(@current_step)
      vote(actor)
    end
  end

  def reject(actor)
    return unless actor.active?

    decrement if actor.can_vote_on_step?(@current_step) || actor.can_force_step?(@current_step)
  end

  def finished?
    @current_step == @steps_config.size
  end

  private

  def increment
    @current_step += 1 unless finished?
  end

  def vote(actor)
    @votes[@current_step] << actor
    increment if @votes[@current_step].size >= @steps_config[@current_step]
  end

  def decrement
    @votes[@current_step] = Set.new
    @current_step -= 1 unless @current_step == 0
    @votes[@current_step] = Set.new
  end
end

class User
  def initialize(permission_table, active = true)
    @permission_table = permission_table
    @active = active
  end

  def can_vote_on_step?(step)
    @permission_table[step] == Permission::VOTE
  end

  def can_force_step?(step)
    @permission_table[step] == Permission::FORCE
  end

  def active?
    @active
  end
end

class Permission
  ALL = [NONE = :none, *(ACTIONABLE = [VOTE = :vote, FORCE = :force])]
end
