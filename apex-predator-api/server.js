const express = require("express");
const cors = require("cors");
const db = require("./database");

const app = express();

app.use(cors());
app.use(express.json());

const PORT = process.env.PORT || 3000;


// Check API status
app.get("/", (req, res) => {
    res.json({ message: "Apex Predator API running!" });
});


// Submit score
app.post("/scores", async (req, res) => {
    const { username, score, level } = req.body || {};

    if (
        typeof username !== "string" ||
        username.trim().length < 1 ||
        username.trim().length > 20 ||
        !Number.isSafeInteger(score) ||
        score < 0 ||
        score > 2147483647 ||
        !Number.isSafeInteger(level) ||
        level < 1 ||
        level > 2147483647
    ) {
        return res.status(400).json({ error: "Invalid score data" });
    }

    try {
        const sql = `
            INSERT INTO scores (username, score, level)
            VALUES ($1, $2, $3)
            RETURNING id
        `;

        const result = await db.query(sql, [
            username.trim(),
            score,
            level
        ]);

        return res.status(201).json({
            id: result.rows[0].id,
            message: "Score saved!"
        });

    } catch (err) {
        console.error("Score submission error:", err.message);
        return res.status(500).json({ error: "Database error" });
    }
});


// Retrieve top 10 scores
app.get("/leaderboard", async (req, res) => {
    try {
        const sql = `
            SELECT username, score, level
            FROM scores
            ORDER BY score DESC, created_at ASC, id ASC
            LIMIT 10
        `;

        const result = await db.query(sql);

        return res.status(200).json(result.rows);

    } catch (err) {
        console.error("Leaderboard error:", err.message);
        return res.status(500).json({ error: "Database error" });
    }
});


app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});