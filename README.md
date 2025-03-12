# Wik

Wik is a collaborative wiki platform built with Elixir and Phoenix, designed to turn Telegram groups into shared knowledge hubs.

By integrating with Telegram’s Bot API, Wik allows group members to seamlessly access and contribute to a private wiki using their existing Telegram accounts, no extra sign-ups required. 

Group membership becomes the key to access: adding a member to the Telegram group automatically grants them access to the wiki, while removing them revokes it.

With Wik, every Telegram group can evolve into a living knowledge base, where information is easy to organize, access, and grow collaboratively.

Wik is perfect for any scenario where a small to medium-sized group needs to collaboratively manage and share knowledge in a structured way, without the friction of setting up a separate platform or managing complex permissions. The seamless Telegram integration makes it ideal for real-time collaboration and easy access.

## Examples of ideal use cases

### Community Knowledge Base

A hobby community (e.g., plant care, gaming) can use Wik to compile guides, FAQs, and shared resources in one place, accessible only to members.

### Study Groups

Students organizing a study group via Telegram can use Wik to compile lecture notes, exam prep materials, and useful links, ensuring that everyone in the group has access to the same resources.

## Why Wik Works Well

✅ **Simple access control:** Group membership = wiki access. 

✅ **Easy onboarding:** No need for separate accounts or user management.

✅ **Low friction:** Accessible directly from Telegram with no additional setup. 

✅ **Real-time updates:** Information stays current as the group evolves.

## Developer Setup

Wik uses several tools to standardize the development environment. Please ensure you have the following installed:

*   **asdf** – for managing Elixir, Erlang, and other language versions. The required versions are specified in the `.tool-versions` file.

### Getting Started

1.  **Install asdf**  
    Follow the [asdf installation guide](https://asdf-vm.com/#/core-manage-asdf) if you haven’t already. Then install the required versions by running:
    
    ```
    asdf install
    ```
    
2.  **Configure direnv**  
    Ensure that asdf-direnv is installed. 
    
    In the project root, you’ll find an `.envrc` file containing:
    
    ```
    dotenv
    ```
    
    Run:
    
    ```
    direnv allow
    ```
    
    This will automatically load your environment variables when you enter the project directory.

3.  **Environment Variables**  
    Copy the example environment file to create your own local configuration:
    
    ```
    cp .env.example .env
    ```
    
    Then fill in your own environment variables in the `.env` file.

4.  **Fetch Dependencies and Setup**  
    Install the dependencies and setup the project by running:
    
    ```
    mix setup
    ```
    
    This command will fetch all dependencies, create and migrate the database, and build the assets.

## Authentication

### Production

*   Wik relies on a **Telegram bot** to authenticate users. In production, the bot acts as a gateway: users logging in through Telegram are verified as members of a specific Telegram group. Only group members gain access to the private space shared among the group.
*   **Important:** Deploying Telegram authentication in production requires that the bot is correctly set up and added to a group. The bot token and other related secrets should be set as environment variables.

### Local Development

*   For local development, fake user logins are provided when you open [localhost:4000](http://localhost:4000). This means you do not need to set up a Telegram bot for everyday testing.
*   If you want to try out real Telegram authentication locally, you can use a tunneling tool such as [zrok](https://zrok.io) to expose your local server to the internet.
*   **Note:** Except when using fake users in development, Telegram login requires the existence of a Telegram bot. Adding the bot to a Telegram group will grant you access to a private space shared among the group members.

## Deployment on Fly.io

1.  **Install flyctl**  
    Install the Fly.io CLI tool by running:
    
    ```
    curl -L https://fly.io/install.sh | sh
    ```
    
    Ensure that the `flyctl` binary is in your PATH.
2.  **Configure Secrets**  
    Set the required secrets (e.g. `SECRET_KEY_BASE`, `BOT_TOKEN`, etc.) by running:
    
    ```
    flyctl secrets set SECRET_KEY_BASE=your_secret_key_here BOT_TOKEN=your_bot_token_here
    ```
    
3.  **Deploy**  
    With Fly.io configured (via your `fly.toml` file), deploy your application using:
    
    ```
    flyctl deploy
    ```
    
    For more details, refer to the [Fly.io documentation](https://fly.io/docs/).

---

Happy coding! 🎉🎉🎉
