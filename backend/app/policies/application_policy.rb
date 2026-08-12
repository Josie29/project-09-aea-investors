# Base class for authorization policies.
#
# Deliberately hand-rolled rather than pulling in Pundit: we need one rule
# (ownership) across a handful of resources, and a base class plus a `deny unless
# explicitly allowed` default is the whole of what Pundit would give us here.
#
# Every predicate defaults to false. A policy that forgets to define an action denies
# it, so the failure mode of an incomplete policy is a locked door rather than an
# open one.
class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def show? = false
  def update? = false
  def destroy? = false
end
