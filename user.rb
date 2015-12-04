require_relative 'permission'

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
