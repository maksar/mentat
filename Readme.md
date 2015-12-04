This is an article about mutation testing – very special methodology among others in a field of unit testing. It is capable to amaze, make you think you lost your mind and, finally, can bring peace into your programmer's soul. I know, it sounds quite loud and pathetic definition, but I hope, that after reading the rest of article, you'll be convinced just like I am now.

Mutation testing technic is based on quite simple idea. Say, you have bunch of code and number of tests to verify the code correctness. Doesn't matter how those tests were born: using technics like TDD or written afterwords. Mutation testing allows to verify that your test suite is 'full'. On 'full' I mean – there is no code (code execution path, to be precisely correct), that is not covered with at least one test case.

Whoa, can you say, but we have code coverage tools! Yes, there are large amount of test coverage tools out there. But most of them collect statistics only about lines coverage (C0 coverage). Basically, it means whether particular line of source code was executed or not.

Its hard to cover all possible program states (actually, its not possible in general case). Consider function `next_char`:
```ruby
def next_char(char)
  char.ord.next.chr
end
```
Quite simple function accepting character and returning next one in ASCII table. To get full C2 coverage, it'd needed to verify it works for every possible char out there (from 0 to 255) along with one more edge case for `"\xFF"`. Slight change to `next_char` function makes it impossible to test:
```ruby
def next_char(char, step)
  (char.ord + step).chr
end
```
To fully cover all input parameter space, we'd need to pass every possible integer value for each char... Ok, I think its clear now why program correctness will always remain in computer science field of academia world. However, there are other kinds of coverage metrics, allowing to gain confidence that your code is actually correct.

C1 is intended to track code branches execution. Each source code line can potentially contain more than one code branch. Think about conditions, loops, early exists and nasty things like `try` operator. To satisfy C1 coverage, tests should contain at least two cases for each of the execution branches. Otherwise, some branches may remain 'un-visited' having, however, C0 coverage on this particular line satisfied.

C2 is called condition coverage. If condition expression consists of more than one sub-expressions (`if a == 2 || b.nil?`), it ensures, that each sub-expression gets evaluated to true and false at least once.

Enough with theory, as programmers we like to have our hands dirty with code. As an example problem, lets
Lets write example program to automate simple workflow business process:
Workflow consists many steps, each of which configured with a threshold value. To proceed to the next step of the workflow, its needed to get number of votes from applicable (according to the voting permissions) users. If a user has enough permissions, its possible for him to force  skip one workflow step. Every user with voting permission can veto current step voting process. Workflow will continue from beginning of previous step. Inactive users cannot vote or reject. User can only vote once on same step.

![](https://raw.githubusercontent.com/maksar/mentat/master/images/animation.gif)

Here is on possible implementation of described workflow (full source code can be found on [GitHub](https://github.com/maksar/mentat/)):
```ruby
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
```

It was written without any tests in mind, but looks robust. All required business features are there: inactive users, duplicate votes, force approves, etc. So, lets tests it! It will be a good idea to actually bring example from diagram to existence.

```ruby
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
```

Running spec is successful indeed. Moreover, `simplecov` claims to have 100% code coverade!
```
➜  mentat git:(master) rspec version_1/workflow_spec.rb

Workflow
  works in real world scenario

Finished in 0.00181 seconds (files took 0.13433 seconds to load)
1 example, 0 failures

Coverage report generated for RSpec to /Users/maksar/projects/mentat/coverage. 40 / 40 LOC (100.0%) covered.
```

![](https://raw.githubusercontent.com/maksar/mentat/master/images/coverage.png)

This is where story might end for mediocre developer. One would think, that since coverage indicates we are good, there is no more work to do left. Well, lets not hurry up, mutant to the rescue!

```
➜  mentat git:(master) mutant -I . -r version_1/workflow_spec.rb --use rspec 'Workflow'
```

[![asciicast](https://asciinema.org/a/31217.png)](https://asciinema.org/a/31217)
