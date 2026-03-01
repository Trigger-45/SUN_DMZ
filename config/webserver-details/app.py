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
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>SecurePortal - Login</title>
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    body, html {
      height: 100%;
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      display: flex;
      justify-content: center;
      align-items: center;
      animation: gradientShift 15s ease infinite;
    }
    @keyframes gradientShift {
      0%, 100% { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); }
      50% { background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%); }
    }
    .login-container {
      background: rgba(255, 255, 255, 0.95);
      backdrop-filter: blur(10px);
      padding: 40px 50px;
      border-radius: 20px;
      box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
      width: 400px;
      text-align: center;
      animation: slideIn 0.5s ease-out;
    }
    @keyframes slideIn {
      from {
        opacity: 0;
        transform: translateY(-30px);
      }
      to {
        opacity: 1;
        transform: translateY(0);
      }
    }
    .logo {
      width: 80px;
      height: 80px;
      margin: 0 auto 20px;
      background: linear-gradient(135deg, #667eea, #764ba2);
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 36px;
      color: white;
      font-weight: bold;
      box-shadow: 0 4px 15px rgba(102, 126, 234, 0.4);
    }
    h2 {
      color: #333;
      margin-bottom: 10px;
      font-size: 28px;
    }
    .subtitle {
      color: #666;
      margin-bottom: 30px;
      font-size: 14px;
    }
    .input-group {
      position: relative;
      margin-bottom: 25px;
      text-align: left;
    }
    .input-group label {
      display: block;
      color: #555;
      font-weight: 600;
      margin-bottom: 8px;
      font-size: 14px;
    }
    input[type="text"], input[type="password"] {
      width: 100%;
      padding: 14px 18px;
      border: 2px solid #e0e0e0;
      border-radius: 10px;
      font-size: 15px;
      transition: all 0.3s ease;
      background: #f8f9fa;
    }
    input[type="text"]:focus, input[type="password"]:focus {
      outline: none;
      border-color: #667eea;
      background: white;
      box-shadow: 0 0 0 4px rgba(102, 126, 234, 0.1);
    }
    input[type="submit"] {
      width: 100%;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      border: none;
      color: white;
      padding: 14px 20px;
      border-radius: 10px;
      cursor: pointer;
      font-size: 16px;
      font-weight: 600;
      transition: all 0.3s ease;
      margin-top: 10px;
      box-shadow: 0 4px 15px rgba(102, 126, 234, 0.4);
    }
    input[type="submit"]:hover {
      transform: translateY(-2px);
      box-shadow: 0 6px 20px rgba(102, 126, 234, 0.6);
    }
    input[type="submit"]:active {
      transform: translateY(0);
    }
    .error {
      background: #fee;
      color: #c33;
      padding: 12px;
      border-radius: 8px;
      margin-bottom: 20px;
      font-size: 14px;
      border-left: 4px solid #c33;
      animation: shake 0.5s;
    }
    @keyframes shake {
      0%, 100% { transform: translateX(0); }
      25% { transform: translateX(-10px); }
      75% { transform: translateX(10px); }
    }
    .footer {
      margin-top: 30px;
      color: #999;
      font-size: 12px;
    }
  </style>
</head>
<body>
  <div class="login-container">
    <div class="logo">🔐</div>
    <h2>Welcome Back</h2>
    <p class="subtitle">Login to access your secure portal</p>
    {% if error %}
      <div class="error">{{ error }}</div>
    {% endif %}
    <form action="{{ url_for('login') }}" method="post">
      <div class="input-group">
        <label for="username">Username</label>
        <input type="text" id="username" name="username" placeholder="Enter your username" required>
      </div>
      <div class="input-group">
        <label for="password">Password</label>
        <input type="password" id="password" name="password" placeholder="Enter your password" required>
      </div>
      <input type="submit" value="Sign In">
    </form>
    <div class="footer">
      SecurePortal v1.0 © 2026
    </div>
  </div>
</body>
</html>
'''

reports_page = '''
<!doctype html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>SecurePortal - Dashboard</title>
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    body {
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%);
      min-height: 100vh;
      padding: 20px;
    }
    .header {
      background: white;
      padding: 20px 40px;
      border-radius: 15px;
      box-shadow: 0 4px 20px rgba(0, 0, 0, 0.1);
      margin-bottom: 30px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      animation: slideDown 0.5s ease-out;
    }
    @keyframes slideDown {
      from {
        opacity: 0;
        transform: translateY(-20px);
      }
      to {
        opacity: 1;
        transform: translateY(0);
      }
    }
    .header h1 {
      color: #333;
      font-size: 28px;
      display: flex;
      align-items: center;
      gap: 15px;
    }
    .user-badge {
      background: linear-gradient(135deg, #667eea, #764ba2);
      color: white;
      padding: 8px 20px;
      border-radius: 20px;
      font-weight: 600;
      font-size: 14px;
      box-shadow: 0 4px 15px rgba(102, 126, 234, 0.3);
    }
    .container {
      max-width: 1200px;
      margin: 0 auto;
    }
    .dashboard-title {
      color: #555;
      margin-bottom: 20px;
      font-size: 20px;
      font-weight: 600;
    }
    .reports-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(400px, 1fr));
      gap: 25px;
      margin-bottom: 30px;
    }
    .report {
      background: white;
      padding: 25px;
      border-radius: 15px;
      box-shadow: 0 4px 20px rgba(0, 0, 0, 0.08);
      transition: all 0.3s ease;
      border-left: 5px solid #667eea;
      animation: fadeIn 0.5s ease-out;
      animation-fill-mode: both;
    }
    @keyframes fadeIn {
      from {
        opacity: 0;
        transform: translateY(20px);
      }
      to {
        opacity: 1;
        transform: translateY(0);
      }
    }
    .report:nth-child(1) { animation-delay: 0.1s; }
    .report:nth-child(2) { animation-delay: 0.2s; }
    .report:nth-child(3) { animation-delay: 0.3s; }
    .report:hover {
      transform: translateY(-5px);
      box-shadow: 0 8px 30px rgba(0, 0, 0, 0.15);
    }
    .report h3 {
      color: #667eea;
      margin-bottom: 15px;
      font-size: 20px;
      display: flex;
      align-items: center;
      gap: 10px;
    }
    .report h3::before {
      content: "📄";
      font-size: 24px;
    }
    .report p {
      color: #666;
      line-height: 1.6;
      font-size: 15px;
    }
    .no-reports {
      background: white;
      padding: 60px;
      border-radius: 15px;
      text-align: center;
      color: #999;
      font-size: 18px;
      box-shadow: 0 4px 20px rgba(0, 0, 0, 0.08);
    }
    .no-reports::before {
      content: "📭";
      display: block;
      font-size: 64px;
      margin-bottom: 20px;
    }
    .logout-btn {
      display: inline-block;
      background: linear-gradient(135deg, #667eea, #764ba2);
      color: white;
      padding: 12px 30px;
      border-radius: 25px;
      text-decoration: none;
      font-weight: 600;
      transition: all 0.3s ease;
      box-shadow: 0 4px 15px rgba(102, 126, 234, 0.3);
    }
    .logout-btn:hover {
      transform: translateY(-2px);
      box-shadow: 0 6px 20px rgba(102, 126, 234, 0.5);
    }
    .logout-container {
      text-align: center;
      margin-top: 30px;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>🔐 SecurePortal Dashboard</h1>
      <div class="user-badge">👤 {{ username }}</div>
    </div>
    
    <h2 class="dashboard-title">Your Accessible Reports</h2>
    
    {% if reports %}
      <div class="reports-grid">
        {% for title, details in reports %}
          <div class="report">
            <h3>{{ title }}</h3>
            <p>{{ details }}</p>
          </div>
        {% endfor %}
      </div>
    {% else %}
      <div class="no-reports">
        No reports available for your account
      </div>
    {% endif %}
    
    <div class="logout-container">
      <a href="{{ url_for('logout') }}" class="logout-btn">🚪 Logout</a>
    </div>
  </div>
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