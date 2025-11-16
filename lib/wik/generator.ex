defmodule Wik.Generator do
  use Ash.Generator

  def user(opts \\ []) do
    changeset_generator(
      Wik.Accounts.User,
      :create,
      defaults: [
        email: sequence(:email, fn i -> "user#{i}@example.com" end)
      ],
      overrides: opts,
      authorize?: Keyword.get(opts, :authorize?, true)
    )
  end

  def group(opts \\ []) do
    # Get or generate the actor (user)  
    actor = opts[:actor] || once(:default_user, fn -> generate(user()) end)

    changeset_generator(
      Wik.Accounts.Group,
      :create,
      defaults: [
        title: sequence(:group_title, fn i -> "Group #{i}" end),
        text: "Description"
      ],
      overrides: opts,
      actor: actor,
      authorize?: Keyword.get(opts, :authorize?, true)
    )
  end
end
