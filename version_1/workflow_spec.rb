require_relative '../spec_helper'

require_relative 'workflow'

describe Workflow do
  subject { Workflow.new([3, 2, 2]) }
  it 'works in real world scenario' do
    subject.approve(voter = User.new([VOTE])) # First vote on first step
    subject.approve(voter) # Subsequent vote does not affect workflow state
    subject.approve(User.new([VOTE])) # Second vote on first workflow step
    subject.approve(User.new([VOTE], false)) # Inactive users cannot affect workflow state
    subject.approve(User.new([VOTE])) # Final vote, workflow proceeds to the next step

    subject.approve(User.new([NONE, FORCE])) # Workflow is forced to proceed to the third step

    subject.reject(User.new([NONE, NONE, VOTE])) # Reject! Falling back to the second step and starting over

    subject.approve(User.new([NONE, VOTE])) # Getting first
    subject.approve(User.new([NONE, VOTE])) # And second vote on second step

    expect do
      subject.approve(User.new([NONE, VOTE, FORCE])) # Completing workflow by skipping voting process on last step
    end.to change { subject.finished? }.from(false).to(true)
  end
end
