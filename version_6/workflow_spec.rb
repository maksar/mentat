require_relative '../spec_helper'

require_relative 'workflow'

describe Workflow do
  context 'empty workflow' do
    subject { Workflow.new([]) }
    it('should raise IndexError on inconsistent configuration') do
      expect { subject.approve(User.new([VOTE])) }.to raise_error(IndexError)
    end
    it('should be already finished') { expect(subject).to be_finished }
    ALL.each do |permission|
      it("should remain finished after #{permission} reject action") do
        expect { subject.reject(User.new(permission)) }.not_to change(subject, :finished?)
      end
      it("should remain finished after #{permission} approve action") do
        expect { subject.approve(User.new(permission)) }.not_to change(subject, :finished?)
      end
    end
  end
  context 'workflow from single step' do
    [0, 1].each do |votes|
      context "where step requires #{votes} votes" do
        subject { Workflow.new([votes]) }
        it('should not be initially finished') { expect(subject).not_to be_finished }
        it('should not be finished after approve from incapable actor') do
          expect { subject.approve(User.new([NONE])) }.not_to change(subject, :finished?)
        end
        ACTIONABLE.each do |permission|
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
      it('finished workflow should react on actions') do
        expect { subject.approve(User.new([FORCE])) }.to change(subject, :finished?).from(false).to(true)
        expect { subject.approve(User.new([FORCE, FORCE])) }.not_to change(subject, :finished?)
        expect { subject.reject(User.new([FORCE, FORCE])) }.not_to change(subject, :finished?)
      end
      it('should be finished only after first force action') do
        expect { subject.approve(User.new([FORCE])) }.to change(subject, :finished?)
      end
      it('should be finished only after second vote action') do
        expect { subject.approve(User.new([VOTE])) }.not_to change(subject, :finished?)
        expect { subject.approve(User.new([VOTE])) }.to change(subject, :finished?)
      end
      it('should not be finished after subsequent vote action of the same actor') do
        subject.approve(actor = User.new([VOTE]))
        expect { subject.approve(actor) }.not_to change(subject, :finished?)
      end
      ACTIONABLE.each do |permission|
        it("should be able to reset votes by reject action from #{permission} actor") do
          subject.approve(User.new([VOTE]))
          subject.reject(User.new([permission]))
          expect { subject.approve(User.new([VOTE])) }.not_to change(subject, :finished?)
          expect { subject.approve(User.new([VOTE])) }.to change(subject, :finished?)
        end
        it("inactive #{permission} actor cannot affect voting process") do
          subject.approve(User.new([VOTE]))
          subject.reject(User.new([permission], false))
          expect { subject.approve(User.new([VOTE])) }.to change(subject, :finished?)
        end
        it('actor without permissions cannot reject') do
          subject.approve(User.new([VOTE]))
          subject.reject(User.new([NONE]))
          expect { subject.approve(User.new([VOTE])) }.to change(subject, :finished?)
        end
      end
    end
  end

  context 'Workflow from three steps' do
    subject { Workflow.new([2, 2, 2]) }
    let(:voter) { -> { User.new([VOTE, VOTE, VOTE]) } }
    it('reject should erase votes from current and previous step') do
      5.times { subject.approve(voter.call) }
      subject.reject(voter.call)
      expect { 3.times { subject.approve(voter.call) } }.not_to change(subject, :finished?)
      expect { subject.approve(voter.call) }.to change(subject, :finished?)
    end
  end
end
