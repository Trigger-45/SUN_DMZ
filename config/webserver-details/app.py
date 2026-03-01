from flask import Flask, request, render_template_string, redirect, url_for, session
import psycopg2
import os

app = Flask(__name__)
app.secret_key = "your-secret-key"  # needed for session management

# DB connection details - use environment variables or defaults
DB_HOST = os.getenv('DB_HOST', '10.0.2.70')
DB_NAME = os.getenv('DB_NAME', 'mydatabase')
DB_USER = os.getenv('DB_USER', 'admin_user')
DB_PASSWORD = os.getenv('DB_PASSWORD', 'securePassword123')
DB_PORT = 5432

def get_db_connection():
    return psycopg2.connect(
        host=DB_HOST,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
        port=DB_PORT
    )

def check_user(username, password):
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute('SELECT password FROM users WHERE username = %s', (username,))
        row = cur.fetchone()
        cur.close()
        conn.close()
        if row and row[0] == password:
            return True
    except Exception as e:
        print(f"DB error: {e}")
    return False

def get_user_reports(username):
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("""
            SELECT r.title, r.details
            FROM reports r
            INNER JOIN user_report_access ufa ON r.report_id = ufa.report_id
            WHERE ufa.username = %s
            ORDER BY r.title
        """, (username,))
        reports = cur.fetchall()
        cur.close()
        conn.close()
        return reports
    except Exception as e:
        print(f"DB error: {e}")
        return []

login_form = '''
<!doctype html>
<html lang="en">
<head>
  <title>Login</title>
  <style>
    body, html {
      height: 100%;
      margin: 0;
      font-family: Arial, sans-serif;
      display: flex;
      justify-content: center;
      align-items: center;
      background: #f0f2f5;
    }
    .login-container {
      background: white;
      padding: 20px 30px;
      border-radius: 8px;
      box-shadow: 0 2px 10px rgba(0,0,0,0.1);
      width: 300px;
      text-align: center;
    }
    input[type="text"], input[type="password"] {
      width: 90%;
      padding: 8px;
      margin: 10px 0 20px 0;
      border: 1px solid #ccc;
      border-radius: 4px;
    }
    input[type="submit"] {
      background-color: #007bff;
      border: none;
      color: white;
      padding: 10px 20px;
      border-radius: 4px;
      cursor: pointer;
      font-size: 16px;
    }
    input[type="submit"]:hover {
      background-color: #0056b3;
    }
    p.error {
      color: red;
      margin: -15px 0 15px 0;
      font-weight: bold;
    }
  </style>
</head>
<body>
  <div class="login-container">
    <h2>Login</h2>
    {% if error %}
      <p class="error">{{ error }}</p>
    {% endif %}
    <form action="{{ url_for('login') }}" method="post">
      <input type="text" name="username" placeholder="Username" required><br/>
      <input type="password" name="password" placeholder="Password" required><br/>
      <input type="submit" value="Log In">
    </form>
  </div>
</body>
</html>
'''

reports_page = '''
<!doctype html>
<html lang="en">
<head>
  <title>Your Reports</title>
  <style>
    body {
      font-family: Arial, sans-serif;
      background: #fafafa;
      margin: 20px;
    }
    h2 {
      color: #333;
    }
    .report {
      background: white;
      padding: 15px;
      margin-bottom: 15px;
      border-radius: 6px;
      box-shadow: 0 1px 5px rgba(0,0,0,0.1);
    }
    .report h3 {
      margin-top: 0;
      color: #007bff;
    }
    .logout {
      margin-top: 20px;
      display: inline-block;
      color: #007bff;
      text-decoration: none;
      font-weight: bold;
    }
    .logout:hover {
      text-decoration: underline;
    }
  </style>
</head>
<body>
  <h2>Reports Accessible for {{ username }}:</h2>
  {% for title, details in reports %}
    <div class="report">
      <h3>{{ title }}</h3>
      <p>{{ details }}</p>
    </div>
  {% else %}
    <p>No reports available.</p>
  {% endfor %}
  <a href="{{ url_for('logout') }}" class="logout">Logout</a>
</body>
</html>
'''

@app.route('/', methods=['GET', 'POST'])
def login():
    error = None
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        if check_user(username, password):
            session['username'] = username
            return redirect(url_for('reports'))
        else:
            error = 'Invalid username or password'
    return render_template_string(login_form, error=error)

@app.route('/reports')
def reports():
    username = session.get('username')
    if not username:
        return redirect(url_for('login'))
    reports = get_user_reports(username)
    return render_template_string(reports_page, username=username, reports=reports)

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('login'))

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=5000)