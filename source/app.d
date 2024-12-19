import vibe.vibe;
import std.random;
import std.conv;
import std.digest.sha;
import std.string;
import core.thread;

// Entry point
void main() {
    igniteServer();
}

// Server ignition...
void igniteServer() {
    auto router = new URLRouter;
    router.get("/", &renderCaptcha);
    router.post("/validate", &verifyAnswer);

    auto settings = new HTTPServerSettings;
    settings.port = 8080;
    settings.bindAddresses = ["0.0.0.0"];

    auto server = listenHTTP(settings, router);

    logInfo("Server blazing on http://127.0.0.1:8080");

    // Keep the server running until interrupted
    while (true) {
        Thread.sleep(dur!"seconds"(1)); // Sleep to reduce CPU usage
    }

    // Cleanup on termination (unreachable without signal handling)
    server.stopListening();
}

// Struct to encapsulate CAPTCHA logic
struct RiddleMachine {
    int a, b;
    string op;
    string correctAnswer;

    string craftRiddle() {
        a = uniform(1, 10);
        b = uniform(1, 10);
        string[] operators = ["+", "-", "*"];
        op = operators[uniform(0, operators.length)];
        correctAnswer = computeSolution();
        return to!string(a) ~ " " ~ op ~ " " ~ to!string(b);
    }

    string computeSolution() {
        switch (op) {
            case "+": return to!string(a + b);
            case "-": return to!string(a - b);
            case "*": return to!string(a * b);
            default: return "error";
        }
    }

    string encrypt(string input) {
        return sha1Of(input).toHexString().idup;
    }
}

// Render CAPTCHA page
void renderCaptcha(HTTPServerRequest req, HTTPServerResponse res) {
    RiddleMachine riddle;
    auto question = riddle.craftRiddle();
    auto encryptedAnswer = riddle.encrypt(riddle.correctAnswer);

    // Store the encrypted answer in a cookie
    Cookie cookie;
    cookie.value = encryptedAnswer;
    cookie.httpOnly = true;
    res.cookies["captcha_hash"] = cookie;

    string page = q{
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>CAPTCHA</title>
        <style>
            body {
                font-family: Arial, sans-serif;
                background-color: "#f4f4f4";
                margin: 0;
                padding: 0;
                display: flex;
                justify-content: center;
                align-items: center;
                height: 100vh;
            }
            .container {
                background-color: "#fff";
                border-radius: 5px;
                box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
                padding: 20px;
                width: 300px;
                text-align: center;
            }
            input[type="text"], button {
                width: 100%;
                padding: 10px;
                margin: 10px 0;
                border-radius: 5px;
                border: 1px solid "#ccc";
            }
            button {
                background-color: "#007bff";
                color: white;
                border: none;
                cursor: pointer;
            }
            button:hover {
                background-color: "#0056b3";
            }
        </style>
    </head>
    <body>
        <div class="container">
            <h2>Solve the Riddle</h2>
            <form method="post" action="/validate">
                <p>Question: }~question~q{</p>
                <input type="text" name="answer" placeholder="answer">
                <button type="submit">Submit</button>
            </form>
        </div>
    </body>
    </html>
    };

    res.writeBody(page, "text/html");
}

// Validate CAPTCHA answer
void verifyAnswer(HTTPServerRequest req, HTTPServerResponse res) {
    string userAnswer = req.form["answer"];
    string encryptedCorrectAnswer = req.cookies.get("captcha_hash", "");

    RiddleMachine riddle;
    if (riddle.encrypt(userAnswer) == encryptedCorrectAnswer) {
        res.writeBody("...Yeap !");
    } else {
        res.writeBody("Wrong.");
    }
}
