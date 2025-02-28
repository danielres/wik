export default function miniappSeamlessAuth(csrfToken) {
    const hashParams = new URLSearchParams(window.location.hash.substring(1));

    if (hashParams.has("tgWebAppData")) {
        const rawData = decodeURIComponent(hashParams.get("tgWebAppData"));

        fetch("/auth/telegram/miniapp", {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "Authorization": `tma ${rawData}`, // Send raw data as Telegram recommends
                "x-csrf-token": csrfToken
            }
        })
            .then(response => response.json())
            .then(data => {
                console.log("Server Response:", data);
                if (data.success) window.location.href = "/"; // Redirect after successful login

            })
            .catch(error => console.error("Error:", error));
    }
};