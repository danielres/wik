defmodule Wik.Users do
  @moduledoc """
  The Users context.
  """

  import Ecto.Query, warn: false
  alias Wik.Repo

  alias Wik.Users.User

  @doc """
  Persists a session user to the database and returns the database user.
  """

  # def persist_session_user(session_user) do
  #   session_user
  #   |> create_or_update_user_by_telegram_id()
  # end

  def find_user_by_telegram_id(telegram_id) do
    Repo.one(from u in User, where: u.telegram_id == ^telegram_id)
  end

  def create_or_update_user_by_telegram_id(user_data) do
    # case Repo.one(from u in User, where: u.telegram_id == ^user_data.telegram_id) do
    case find_user_by_telegram_id(user_data.telegram_id) do
      nil ->
        create_user(user_data)

      u ->
        update_user(u, user_data)
    end
  end

  @doc """
  Returns the list of users.

  ## Examples

      iex> list_users()
      [%User{}, ...]

  """
  def list_users do
    Repo.all(User)
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Creates a user.

  ## Examples

      iex> create_user(%{field: value})
      {:ok, %User{}}

      iex> create_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user.

  ## Examples

      iex> update_user(user, %{field: new_value})
      {:ok, %User{}}

      iex> update_user(user, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a user.

  ## Examples

      iex> delete_user(user)
      {:ok, %User{}}

      iex> delete_user(user)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user(%User{} = user, attrs \\ %{}) do
    User.changeset(user, attrs)
  end

  @doc """
  Updates `last_seen` if it’s nil or more than `update_interval` seconds old.
  Returns `{:ok, %User{}}` or `{:error, changeset}`.
  """
  def update_last_seen(%User{} = user) do
    now = DateTime.utc_now()
    update_interval = 60

    update? =
      is_nil(user.last_seen) ||
        DateTime.diff(now, user.last_seen, :second) > update_interval

    if update? do
      update_user(user, %{last_seen: now})
    else
      {:ok, user}
    end
  end

  def update_last_seen(user_id) do
    # Convert to string if it's not already
    # user_id = to_string(user_id)

    case Repo.get(User, user_id) do
      nil ->
        # User doesn't exist in the database
        IO.warn("[Users.update_last_seen(user_id)] User with ID #{user_id} not found.")
        {:error, :user_not_found}

      user ->
        update_last_seen(user)
    end
  end
end
