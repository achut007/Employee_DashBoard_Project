from flask import Flask, jsonify, request
import psycopg2
import os
import time

app = Flask(__name__)

DB_HOST = os.getenv('DB_HOST', 'db')
DB_NAME = os.getenv('POSTGRES_DB', 'testdb')
DB_USER = os.getenv('POSTGRES_USER', 'admin')
DB_PASS = os.getenv('POSTGRES_PASSWORD', 'password')


def get_connection():
    return psycopg2.connect(
        host=DB_HOST,
        database=DB_NAME,
        user=DB_USER,
        password=DB_PASS
    )


def initialize_table():

    retries = 5

    while retries > 0:

        try:

            conn = get_connection()
            cur = conn.cursor()

            cur.execute("""
                CREATE TABLE IF NOT EXISTS employees (
                    id SERIAL PRIMARY KEY,
                    name VARCHAR(100),
                    department VARCHAR(100)
                )
            """)

            conn.commit()
            cur.close()
            conn.close()

            print("Database Connected Successfully")
            return

        except Exception as e:

            print(f"Database not ready, retrying... ({e})")
            retries -= 1
            time.sleep(5)

    print("Failed to connect to database after retries")


initialize_table()


@app.route('/')
def home():
    return jsonify({
        "message": "Hello from API"
    })


# READ
@app.route('/employees', methods=['GET'])
def get_employees():

    conn = get_connection()
    cur = conn.cursor()

    cur.execute("SELECT * FROM employees ORDER BY id")
    rows = cur.fetchall()

    employees = [
        {"id": row[0], "name": row[1], "department": row[2]}
        for row in rows
    ]

    cur.close()
    conn.close()

    return jsonify(employees)


# CREATE
@app.route('/employees', methods=['POST'])
def add_employee():

    data = request.get_json()

    if not data or 'name' not in data or 'department' not in data:
        return jsonify({"error": "name and department are required"}), 400

    conn = get_connection()
    cur = conn.cursor()

    cur.execute(
        "INSERT INTO employees (name, department) VALUES (%s, %s)",
        (data['name'], data['department'])
    )

    conn.commit()
    cur.close()
    conn.close()

    return jsonify({"message": "Employee Added Successfully"}), 201


# UPDATE
@app.route('/employees/<int:id>', methods=['PUT'])
def update_employee(id):

    data = request.get_json()

    if not data or 'name' not in data or 'department' not in data:
        return jsonify({"error": "name and department are required"}), 400

    conn = get_connection()
    cur = conn.cursor()

    cur.execute(
        "UPDATE employees SET name=%s, department=%s WHERE id=%s",
        (data['name'], data['department'], id)
    )

    conn.commit()
    cur.close()
    conn.close()

    return jsonify({"message": "Employee Updated Successfully"})


# DELETE
@app.route('/employees/<int:id>', methods=['DELETE'])
def delete_employee(id):

    conn = get_connection()
    cur = conn.cursor()

    cur.execute("DELETE FROM employees WHERE id=%s", (id,))

    conn.commit()
    cur.close()
    conn.close()

    return jsonify({"message": "Employee Deleted Successfully"})


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
