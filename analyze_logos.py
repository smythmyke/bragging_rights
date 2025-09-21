import json
with open("rangers_devils_data.json", "r") as f:
    data = json.load(f)

print("🏒 LOGO URL ANALYSIS")
print("==================")

# Check header > competitions > competitors
header = data.get("header", {})
competitions = header.get("competitions", [])
if competitions:
    competition = competitions[0]
    competitors = competition.get("competitors", [])
    print(f"Competitors found: {len(competitors)}")
    for i, competitor in enumerate(competitors):
        team = competitor.get("team", {})
        print(f"Team {i+1}:")
        print(f"  Name: {team.get("displayName", "Unknown")}")
        print(f"  Abbreviation: {team.get("abbreviation", "Unknown")}")
        print(f"  Logo URL: {team.get("logo", "NO LOGO")}")
        print(f"  Home/Away: {competitor.get("homeAway", "Unknown")}")
        print()

# Check boxscore > teams  
boxscore = data.get("boxscore", {})
teams = boxscore.get("teams", [])
if teams:
    print("
Boxscore Teams:")
    for i, team_data in enumerate(teams):
        team = team_data.get("team", {})
        print(f"Team {i+1}:")
        print(f"  Name: {team.get("displayName", "Unknown")}")
        print(f"  Logo URL: {team.get("logo", "NO LOGO")}")
        print()
