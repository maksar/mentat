require 'simplecov'
SimpleCov.start

require 'rspec'
require 'pry'
require_relative 'workflow'

describe Workflow do
  context 'empty workflow' do
    subject { Workflow.new([]) }
    it('should be already finished') { expect(subject).to be_finished }
    Permission::ALL.each do |permission|
      it("should remain finished after #{permission} reject action") do
        expect { subject.reject(User.new(permission)) }.not_to change(subject, :finished?)
      end
      it("should remain finished after #{permission} approve action") do
        expect { subject.reject(User.new(permission)) }.not_to change(subject, :finished?)
      end
    end
  end
  context 'workflow from single step' do
    [0, 1].each do |votes|
      context "where step requires #{votes} votes" do
        subject { Workflow.new([votes]) }
        it('should not be initially finished') { expect(subject).not_to be_finished }
        it('should not be finished after approve from incapable actor') do
          expect { subject.approve(User.new([Permission::NONE])) }.not_to change(subject, :finished?)
        end
        Permission::ACTIONABLE.each do |permission|
          it("should be finished after #{permission} approve action") do
            expect { subject.approve(User.new([permission])) }.to change(subject, :finished?)
          end
          it("should not be finished after inactive actors #{permission} actions") do
            expect { subject.approve(User.new([permission], false)) }.not_to change(subject, :finished?)
          end
        end
      end
    end
    context 'where step requires two votes' do
      subject { Workflow.new([2]) }
      it('should be finished only after first force action') do
        expect { subject.approve(User.new([Permission::FORCE])) }.to change(subject, :finished?)
      end
      it('should be finished only after second vote action') do
        expect { subject.approve(User.new([Permission::VOTE])) }.not_to change(subject, :finished?)
        expect { subject.approve(User.new([Permission::VOTE])) }.to change(subject, :finished?)
      end
      it('should not be finished after subsequent vote action of the same actor') do
        subject.approve(actor = User.new([Permission::VOTE]))
        expect { subject.approve(actor) }.not_to change(subject, :finished?)
      end
      Permission::ACTIONABLE.each do |permission|
        it("should be able to reset votes by reject action from #{permission} actor") do
          subject.approve(User.new([Permission::VOTE]))
          subject.reject(User.new([permission]))
          expect { subject.approve(User.new([Permission::VOTE])) }.not_to change(subject, :finished?)
          expect { subject.approve(User.new([Permission::VOTE])) }.to change(subject, :finished?)
        end
      end
    end
  end
  context 'workflow from many steps' do
    subject { Workflow.new([2, 3, 1]) }
    it 'works in real world scenarios' do
      subject.approve(User.new([Permission::FORCE])) # Forces workflow to the second step
      subject.approve(User.new([Permission::NONE, Permission::VOTE])) # Gaining one vote on second step
      subject.approve(User.new([Permission::NONE, Permission::VOTE])) # Gaining second vote on second step
      subject.approve(User.new([Permission::VOTE], false)) # Nothing changed, actor isn't active
      subject.reject(User.new([Permission::VOTE], false)) # Nothing changed, actor isn't active
      subject.reject(User.new([Permission::NONE, Permission::VOTE])) # In the beginning of the first step again
      subject.approve(voter = User.new([Permission::VOTE, Permission::NONE, Permission::VOTE])) # Gaining one vote
      subject.approve(User.new([Permission::FORCE], false)) # Trying to use force...
      subject.approve(voter) # Trying to vote again...
      subject.approve(User.new([Permission::VOTE])) # Finally moving to the second step
      subject.approve(User.new([Permission::NONE, Permission::NONE])) # Again, doing nothing, lack of permissions
      subject.approve(User.new([Permission::NONE, Permission::FORCE])) # Finally, on third step
      subject.approve(voter) # Now, workflow should be finished
      expect(subject).to be_finished
    end
  end
end
