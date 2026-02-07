defmodule Wik.Accounts.User do
  use Ash.Resource,
    otp_app: :wik,
    domain: Wik.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAuthentication]

  defimpl String.Chars do
    def to_string(user) do
      Kernel.to_string(user.tg_username)
    end
  end

  authentication do
    add_ons do
      log_out_everywhere do
        apply_on_password_change? true
      end
    end

    tokens do
      enabled? true
      token_resource Wik.Accounts.Token
      signing_secret Wik.Secrets
      store_all_tokens? true
      require_token_presence_for_authentication? true
    end

    strategies do
      magic_link do
        identity_field :email
        registration_enabled? true
        require_interaction? true

        sender Wik.Accounts.User.Senders.SendMagicLinkEmail
      end
    end
  end

  postgres do
    table "users"
    repo Wik.Repo
  end

  actions do
    defaults [:read]

    read :get_by_subject do
      description "Get a user by the subject claim in a JWT"
      argument :subject, :string, allow_nil?: false
      get? true
      prepare AshAuthentication.Preparations.FilterBySubject
    end

    read :get_by_email do
      description "Looks up a user by their email"
      argument :email, :string, allow_nil?: false
      get_by :email
    end

    create :create do
      primary? true
      accept [:email, :tg_id, :tg_first_name, :tg_last_name, :tg_username, :tg_photo_url]
    end

    create :sign_in_with_magic_link do
      description "Sign in or register a user with magic link."

      argument :token, :string do
        description "The token from the magic link that was sent to the user"
        allow_nil? false
      end

      upsert? true
      upsert_identity :unique_email
      upsert_fields [:email]

      # Uses the information from the token to create or sign in the user
      change AshAuthentication.Strategy.MagicLink.SignInChange

      metadata :token, :string do
        allow_nil? false
      end
    end

    action :request_magic_link do
      argument :email, :ci_string do
        allow_nil? true
      end

      run AshAuthentication.Strategy.MagicLink.Request
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    policy action_type(:read) do
      # Users can read themselves  
      authorize_if expr(id == ^actor(:id))

      # Users can read other users if they share a group  
      authorize_if expr(
                     exists(
                       group_user_relations,
                       exists(group.group_user_relations, user_id == ^actor(:id))
                     )
                   )
    end

    policy action_type(:create) do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :ci_string do
      allow_nil? true
      public? true
    end

    attribute :confirmed_at, :utc_datetime_usec

    attribute :role, :atom do
      public? true
      constraints one_of: [:user, :admin, :moderator]
      default :user
    end

    attribute :tz, :string do
      public? true
    end

    attribute :tg_id, :string do
      public? true
    end

    attribute :tg_first_name, :string do
      public? true
    end

    attribute :tg_last_name, :string do
      public? true
    end

    attribute :tg_username, :string do
      public? true
    end

    attribute :tg_photo_url, :string do
      public? true
    end
  end

  relationships do
    has_many :group_user_relations, Wik.Accounts.GroupUserRelation do
      destination_attribute :user_id
    end

    many_to_many :groups, Wik.Accounts.Group do
      join_relationship :group_user_relations
      source_attribute_on_join_resource :user_id
      destination_attribute_on_join_resource :group_id
    end
  end

  identities do
    identity :unique_email, [:email]
    identity :unique_tg_id, [:tg_id]
  end
end
