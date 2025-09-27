# Edge Cards Master Guide - All Sports

## Overview
Edge Cards are premium features designed to provide users with advanced analytics and betting insights. Each sport will have 2-3 Edge Cards focused on two main categories:
1. **Analytics & Insights** - Advanced statistics, predictions, and performance analysis
2. **Betting Intelligence** - Odds movements, trends, and betting strategies

---

## 🏈 NFL (National Football League)

### 📊 Analytics Card
- **Win Probability Graph**: Real-time probability with momentum shifts throughout the game
- **Drive Efficiency**: Success rate, yards per drive, scoring percentage
- **Red Zone Performance**: TD percentage when in red zone (20 yards from goal)
- **Third Down Conversions**: Success rates on crucial downs
- **Time of Possession Analysis**: Which team controls the game tempo
- **Momentum Tracker**: Key plays that shift game momentum
- **Clutch Performance**: Performance in final 2 minutes of halves

### 💰 Betting Insights Card
- **Live Odds Movement**: Real-time spread and total adjustments
- **ATS Records**: Against the spread performance (home/away/division)
- **Over/Under Trends**: Team and matchup scoring patterns
- **Quarter/Half Betting**: First half vs second half performance
- **Player Prop Performance**: Key player prop tracking and trends
- **Public vs Sharp Money**: Where smart money is going
- **Historical Matchup ATS**: How teams perform against each other ATS

### 🌤️ Weather & Conditions Card (Outdoor Games Only)
- **Current Conditions**: Temperature, wind speed/direction, precipitation
- **Impact Analysis**: How weather affects passing game, kicking game
- **Historical Performance**: Teams' records in similar conditions
- **Fantasy Adjustments**: Weather impact on player projections
- **Betting Adjustments**: How weather affects totals and spreads

---

## ⚾ MLB (Baseball)

### 📊 Analytics Card
- **Pitcher Matchup Analysis**: ERA, WHIP, K/9, recent form
- **Batter vs Pitcher History**: Individual matchup statistics
- **Bullpen Performance**: Relief pitcher effectiveness
- **Run Expectancy**: Based on current game situation
- **Exit Velocity & Launch Angle**: Advanced hitting metrics
- **Defensive Shifts Impact**: How positioning affects outcomes

### 💰 Betting Insights Card
- **First 5 Innings Lines**: F5 betting opportunities
- **Run Line Trends**: -1.5/+1.5 performance
- **Over/Under Patterns**: Park factors, weather impact
- **Prop Bet Analysis**: Strikeout props, hit props
- **Umpire Tendencies**: How umpires affect totals

---

## ⚽ SOCCER (Football)

### 📊 Analytics Card
- **xG (Expected Goals)**: Quality of chances created
- **Possession Heat Maps**: Where teams control the ball
- **Shot Maps**: Location and quality of shots
- **Pressing Intensity**: High press success rates
- **Set Piece Efficiency**: Corners and free kick conversion
- **Player Performance Ratings**: Real-time player ratings

### 💰 Betting Insights Card
- **Asian Handicap Trends**: AH performance patterns
- **Both Teams to Score (BTTS)**: Historical BTTS rates
- **Corner & Card Markets**: Disciplinary and corner trends
- **In-Play Opportunities**: Live betting value spots
- **Goal Timing Patterns**: When teams typically score

---

## 🏀 NBA (Basketball)

### 📊 Analytics Card
- **Win Probability Graph**: Real-time probability tracking
- **Momentum Tracker**: Runs and momentum shifts
- **Clutch Performance**: Final 5 minutes statistics
- **Plus/Minus Analysis**: Impact of each player on court
- **Offensive/Defensive Efficiency**: Points per 100 possessions
- **Pace Analysis**: Game tempo and its effects
- **Shot Chart Heat Maps**: Where teams are scoring from

### 💰 Betting Insights Card
- **ATS Records**: Against the spread by situation
- **Over/Under Trends**: Pace-adjusted scoring patterns
- **Quarter/Half Betting**: Period-specific performance
- **Live Betting Opportunities**: In-game value identification
- **Player Prop Analysis**: Points, rebounds, assists props
- **Back-to-Back Performance**: How teams perform on rest

### 🎯 Matchup Intelligence Card
- **Key Matchup Analysis**: Position-by-position breakdown
- **Three-Point Defense**: 3PT shooting matchup
- **Paint Dominance**: Inside scoring advantage
- **Bench Impact**: Second unit performance
- **Coaching Adjustments**: Strategic tendencies

---

## 🏒 NHL (Hockey) - *To Be Implemented*

### 📊 Analytics Card
- **Corsi & Fenwick**: Advanced possession metrics
- **Expected Goals (xG)**: Shot quality analysis
- **Power Play Efficiency**: Special teams performance
- **Goalie Performance**: Save percentage by situation
- **Zone Entry Success**: Offensive zone entry rates

### 💰 Betting Insights Card
- **Puck Line Trends**: -1.5/+1.5 performance
- **Period Betting**: Best periods for teams
- **Over/Under Patterns**: Goalie matchup impact
- **Prop Markets**: Shot props, point props
- **Empty Net Situations**: Late game scenarios

---

## 🥊 BOXING - *To Be Implemented*

### 📊 Analytics Card
- **CompuBox Statistics**: Punch stats and accuracy
- **Fighter Form Analysis**: Recent performance trends
- **Style Matchup**: How styles match up
- **Championship Round Performance**: Late round statistics
- **Knockdown History**: Power punch effectiveness

### 💰 Betting Insights Card
- **Method of Victory**: KO/TKO/Decision trends
- **Round Betting**: When fighters typically win
- **Over/Under Rounds**: Fight duration patterns
- **Prop Bets**: Knockdown props, decision props
- **Judge Tendencies**: How judges score fights

---

## 🥋 MMA/UFC - *To Be Implemented*

### 📊 Analytics Card
- **Strike Accuracy**: Significant strikes landed
- **Takedown Success**: Wrestling effectiveness
- **Submission Attempts**: Ground game threats
- **Octagon Control**: Who dictates the fight
- **Damage Assessment**: Visual damage and impact

### 💰 Betting Insights Card
- **Method of Victory**: Finish type probabilities
- **Round Betting**: When fights typically end
- **Over/Under Rounds**: Fight duration analysis
- **Prop Markets**: Finish props, round props
- **Live Betting**: Momentum shift opportunities

---

## 🎾 TENNIS - *To Be Implemented*

### 📊 Analytics Card
- **Serve Statistics**: First serve %, aces, double faults
- **Break Point Conversion**: Crucial point performance
- **Rally Length Analysis**: Point construction patterns
- **Surface Performance**: Clay/Grass/Hard court stats
- **Head-to-Head Patterns**: Historical matchup trends

### 💰 Betting Insights Card
- **Set Betting**: Correct score predictions
- **Game Handicaps**: Games won/lost spreads
- **Over/Under Games**: Total games patterns
- **In-Play Opportunities**: Momentum shifts
- **Tie-Break Predictions**: Tie-break likelihood

---

## Implementation Priority

1. **Completed**: MLB, Soccer, NBA, NFL
2. **Next Up**: NHL, Tennis
3. **Future**: MMA/UFC, Boxing

## Pricing Strategy Considerations

### Tiered Access
- **Basic**: 1 Edge Card per sport
- **Premium**: All Edge Cards for selected sports
- **Elite**: All Edge Cards for all sports

### Individual Card Pricing
- Analytics Card: $X/month
- Betting Card: $Y/month
- Bundle: $(X+Y-discount)/month

---

## Technical Implementation Notes

### Data Sources Required
- **Analytics**: ESPN API, proprietary calculations
- **Betting**: Odds API, historical betting data
- **Weather**: Weather API (for outdoor sports)
- **Advanced Stats**: Sport-specific APIs (NHL API, NBA API, etc.)

### Caching Strategy
- Edge Card data should be cached differently than basic data
- Premium data refresh rates:
  - Live games: 30 seconds
  - Upcoming (< 1 hour): 5 minutes
  - Future games: 30 minutes

### UI/UX Considerations
- Lock icon for non-subscribers
- Preview/teaser of data to entice upgrades
- Smooth animations for live updates
- Mobile-optimized card layouts

---

*Last Updated: December 2024*
*Version: 1.0*