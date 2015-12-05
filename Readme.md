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

What? Only 64.71%? It sounds very... sobering. Lets see what just happened. We specified mutation target ('Workflow' string in the command line), mutant went over class and detected 7 mutation subjects. For each subject, its constructed AST (Abstract Syntax Tree) of the code and tried to apply different 'mutations' to it. Mutations are small code changes, for example: flipping condition to be opposite, removing line of code, changing constant value, etc. Mutations are easier to deal with working with AST instead of plain text, thats why mutant parses your code, applies mutation (new Mutant is born) and then converts AST back to code, to lets rspec execute tests agains it (attempt to kill the Mutant). If all tests are passed, Mutant remains alive. Think about it. Someone just deleted whole line from your code, and tests are still passing... That basically means, that test suite does not contain enough examples to cover all execution branches.

Ok, on the screenshot above, mutant claims, that if we'd removed condition check inside `vote` method, tests will continue to work. Hard to believe, lets verify:
```ruby
  def vote(actor)
    @votes[@current_step] << actor
    increment
  end
```

Code is changed, running specs:
```
➜  mentat git:(master) rspec version_1/workflow_spec.rb -f p
.

Finished in 0.00144 seconds (files took 0.08017 seconds to load)
1 example, 0 failures
```

Zero failures! It surprises me every time... After staring at other alive Mutants I finally realized how stupid I was, thinking one test case proves correctness or can protect me from regressions. Ok, enough being dumb, we can do better. This time I tried to write very extensive test suite, covering every business feature one-by-one:
```ruby
describe Workflow do
  context 'empty workflow' do
    subject { Workflow.new([]) }
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
    it('reject should erase votes from current and previous step') do
      subject.approve(User.new([FORCE]))
      subject.approve(User.new([VOTE, VOTE]))
      subject.approve(User.new([VOTE, VOTE]))
      subject.reject(User.new([VOTE, VOTE, VOTE]))
      expect { subject.approve(User.new([FORCE, FORCE, FORCE])) }.not_to change(subject, :finished?)
      expect { subject.approve(User.new([FORCE, FORCE, FORCE])) }.to change(subject, :finished?)
    end
  end
end
```

Lets run our ~~enemy~~friend mutant once again:

[![asciicast](https://asciinema.org/a/31226.png)](https://asciinema.org/a/31226)

Much better this time, 91.33% But not perfect, lets see why:
```diff
 def vote(actor)
-  @votes[@current_step] << actor
+  @votes.fetch(@current_step) << actor
   if (@votes[@current_step].size >= @steps_config[@current_step])
     increment
   end
 end ```
This time, one of the mutant's complains was about using `.fetch` method instead of just `[]` accessor. You might think its not a big of a deal, but it worth too think deeper. Difference between `[]` and `fetch` semantic is in behavior on absent values: `[]` will silently return 'nil', where is `fetch` will raise `KeyError` error. So, instead of just substituting hash accessors in our code to more strict version, lets think what mutant is actually trying to tell us... His message is: there might be a problem with error handling in our code or our test suite does not have a case, forcing our code to supper from `NoMethodError` on `nil` values.

Ok, lets try to write one:
```ruby
it('should not raise error on inconsistent configuration') do
  expect { Workflow.new([]).approve(User.new([VOTE])) }.not_to raise_error
end
```
If predictively fails, old good `NotMethodError`:
```
Workflow
  empty workflow
    should not raise error on inconsistent configuration (FAILED - 1)

Failures:

  1) Workflow empty workflow should not raise error on inconsistent configuration
     Failure/Error: expect { Workflow.new([]).approve(User.new([VOTE])) }.not_to raise_error

       expected no Exception, got #<NoMethodError: undefined method `<<' for nil:NilClass> with backtrace:
         # ./version_2/workflow.rb:36:in `vote'
         # ./version_2/workflow.rb:15:in `approve'
         # ./version_2/workflow_spec.rb:9:in `block (4 levels) in <top (required)>'
         # ./version_2/workflow_spec.rb:9:in `block (3 levels) in <top (required)>'
     # ./version_2/workflow_spec.rb:9:in `block (3 levels) in <top (required)>'

Finished in 0.00971 seconds (files took 0.08025 seconds to load)
1 example, 1 failure
```

What we can do about it? Lets actually try to change from mutant. `vote` method now looks like this:
```ruby
  def vote(actor)
    @votes.fetch(@current_step) << actor

    increment if @votes[@current_step].size >= @steps_config[@current_step]
  end
```

Running test again gives different `IndexError` error:
```
Workflow
  empty workflow
    should not raise error on inconsistent configuration (FAILED - 1)

Failures:

  1) Workflow empty workflow should not raise error on inconsistent configuration
     Failure/Error: expect { Workflow.new([]).approve(User.new([VOTE])) }.not_to raise_error

       expected no Exception, got #<IndexError: index 0 outside of array bounds: 0...0> with backtrace:
         # ./version_2/workflow.rb:36:in `fetch'
         # ./version_2/workflow.rb:36:in `vote'
         # ./version_2/workflow.rb:15:in `approve'
         # ./version_2/workflow_spec.rb:9:in `block (4 levels) in <top (required)>'
         # ./version_2/workflow_spec.rb:9:in `block (3 levels) in <top (required)>'
     # ./version_2/workflow_spec.rb:9:in `block (3 levels) in <top (required)>'

Finished in 0.01043 seconds (files took 0.0895 seconds to load)
1 example, 1 failure
```

This one is actually much better to work with. Code blows up exactly where it should, on code, containing accessing error, not later. In previous run it failed on `<<` operator, which, in real world examples, may be far away from the place containing error.

Ok, we learned something useful, lets not waste time on actually fixing it properly. Instead, I'll just pretend, `IndexError` is desired behavior and replace all hash and array accessing methods to be `fetch`:
```ruby
subject { Workflow.new([]) }
it('should raise IndexError on inconsistent configuration') do
  expect { subject.approve(User.new([VOTE])) }.to raise_error(IndexError)
end
```

Running mutant again:
[![asciicast](https://asciinema.org/a/31227.png)](https://asciinema.org/a/31227)

Better results: 92.95% Whats next?
```diff
 def increment
-  unless finished?
-    @current_step += 1
-  end
+  @current_step += 1
 end
 ```

Surprising again. I'm convinced in mutant now and will not try to double-check it by myself. It looks like we did not checked the case where somebody attempts to work with finished workflow, which forces `@current_step` variable to increase and `@current_step == @steps_config.size` invariant does not work anymore. Introducing test and fixing code:

 ```ruby
subject { Workflow.new([2]) }
it('finished workflow should react on actions') do
  expect { subject.approve(User.new([FORCE])) }.to change(subject, :finished?).from(false).to(true)
  expect { subject.approve(User.new([FORCE, FORCE])) }.not_to change(subject, :finished?)
  expect { subject.reject(User.new([FORCE, FORCE])) }.not_to change(subject, :finished?)
end

def increment
  return if finished?
  @current_step += 1
end

def decrement
  return if finished?
  @votes[@current_step] = Set.new
  @current_step -= 1 unless @current_step == 0
  @votes[@current_step] = Set.new
end
```

Mutant shows 94.17% of mutation coverage now, complaining to equality semantics:
```diff
 def finished?
-  @current_step == @steps_config.size
+  @current_step.equal?(@steps_config.size)
 end
 ```

This is similar to the `[]` vs `fetch` case. Mutant again states, that using more srict code (see here!!!! for details) doesn't brake the tests. In our case it doesn't matter (`equal?` on integers is pretty straight-forward), but in real projects, especially with hashes and custom implementation of `hash` function may lead to problems. So, replacing comparison with `equal?` and running mutant:

```ruby
def finished?
  @current_step.equal?(@steps_config.size)
end

def decrement
  return if finished?
  @votes[@current_step] = Set.new
  @current_step -= 1 unless @current_step.zero?
  @votes[@current_step] = Set.new
end
```

Mutation coverage is now 95.25%, we are close to finish:
```diff
 def decrement
   if finished?
     return
   end
   @votes[@current_step] = Set.new
   unless @current_step.zero?
     @current_step -= 1
   end
-  @votes[@current_step] = Set.new
 end
 ```

This last line is there to reset any votes on the step workflow rejects to. I think our tests only using `FORCE` permission after reject, that is why removing this line does not break the suite. In fact, there is `VOTE` activity after `reject` action in `should be able to reset votes by reject action from #{permission} actor` case, but since workflow contains only one step, `@current_step` does not decrements. We need to modify `reject should erase votes from current and previous step` case slightly:
```ruby
subject { Workflow.new([2, 2, 2]) }
let(:voter) { -> { User.new([VOTE, VOTE, VOTE]) } }
it('reject should erase votes from current and previous step') do
  5.times { subject.approve(voter.call) }
  subject.reject(voter.call)
  expect { 3.times { subject.approve(voter.call) } }.not_to change(subject, :finished?)
  expect { subject.approve(voter.call) }.to change(subject, :finished?)
end
```

Now, when all Mutants have been killed, mutant happily reports 100% mutation coverage.
```
Mutant configuration:
Matcher:         #<Mutant::Matcher::Config match_expressions: [Workflow]>
Integration:     Mutant::Integration::Rspec
Expect Coverage: 100.00%
Jobs:            8
Includes:        ["."]
Requires:        ["version_6/workflow_spec.rb"]
Subjects:        7
Mutations:       316
Results:         316
Kills:           316
Alive:           0
Runtime:         8.57s
Killtime:        33.80s
Overhead:        -74.66%
Mutations/s:     36.89
Coverage:        100.00%
Expected:        100.00%
```
