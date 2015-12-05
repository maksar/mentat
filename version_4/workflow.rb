require 'set'

class Workflow
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
    return if finished?
    @current_step += 1
  end

  def vote(actor)
    (votes = @votes.fetch(@current_step)) << actor

    increment if votes.size >= @steps_config.fetch(@current_step)
  end

  def decrement
    return if finished?
    @votes[@current_step] = Set.new
    @current_step -= 1 unless @current_step == 0
    @votes[@current_step] = Set.new
  end
end
