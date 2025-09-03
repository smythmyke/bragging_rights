// ESPN API Explorer - Test various endpoints for granular data
const fetch = require('node-fetch');

// Test endpoints
const endpoints = {
  // NBA game for testing
  nbaScoreboard: 'https://site.api.espn.com/apis/site/v2/sports/basketball/nba/scoreboard',
  nbaGameSummary: 'https://site.api.espn.com/apis/site/v2/sports/basketball/nba/summary?event=401584894',
  nbaPlayByPlay: 'https://site.api.espn.com/apis/site/v2/sports/basketball/nba/playbyplay?gameId=401584894',
  
  // NFL game for testing  
  nflScoreboard: 'https://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard',
  nflGameSummary: 'https://site.api.espn.com/apis/site/v2/sports/football/nfl/summary?event=401547352',
  nflPlayByPlay: 'https://site.api.espn.com/apis/site/v2/sports/football/nfl/playbyplay?gameId=401547352',
  
  // MMA/UFC for individual sport
  mmaScoreboard: 'https://site.api.espn.com/apis/site/v2/sports/mma/ufc/scoreboard',
  mmaFightSummary: 'https://site.api.espn.com/apis/site/v2/sports/mma/ufc/summary?event=401584894',
  
  // Tennis for individual sport
  tennisScoreboard: 'https://site.api.espn.com/apis/site/v2/sports/tennis/scoreboard',
  
  // Baseball for innings
  mlbScoreboard: 'https://site.api.espn.com/apis/site/v2/sports/baseball/mlb/scoreboard',
  mlbGameSummary: 'https://site.api.espn.com/apis/site/v2/sports/baseball/mlb/summary?event=401584894',
};

async function exploreEndpoint(name, url) {
  console.log(`\n${'='.repeat(60)}`);
  console.log(`Testing: ${name}`);
  console.log(`URL: ${url}`);
  console.log('='.repeat(60));
  
  try {
    const response = await fetch(url);
    const data = await response.json();
    
    // Explore game state data
    if (data.events && data.events.length > 0) {
      const event = data.events[0];
      console.log('\nEvent Status:', JSON.stringify(event.status, null, 2));
      
      if (event.competitions && event.competitions[0]) {
        const competition = event.competitions[0];
        
        // Check for situation data (down & distance, etc)
        if (competition.situation) {
          console.log('\nGame Situation:', JSON.stringify(competition.situation, null, 2));
        }
        
        // Check for game details
        if (competition.details) {
          console.log('\nGame Details:', JSON.stringify(competition.details, null, 2));
        }
        
        // Check for plays
        if (competition.plays) {
          console.log('\nSample Play:', JSON.stringify(competition.plays[0], null, 2));
        }
      }
    }
    
    // For summary endpoints
    if (data.header) {
      console.log('\nGame Header:', JSON.stringify(data.header, null, 2));
    }
    
    if (data.plays && data.plays.length > 0) {
      console.log('\nLatest Plays (first 3):');
      data.plays.slice(0, 3).forEach(play => {
        console.log(JSON.stringify(play, null, 2));
      });
    }
    
    // For MMA/Boxing rounds
    if (data.rounds) {
      console.log('\nRounds Data:', JSON.stringify(data.rounds, null, 2));
    }
    
    // For tennis sets/games
    if (data.sets) {
      console.log('\nSets Data:', JSON.stringify(data.sets, null, 2));
    }
    
    // Check what fields are available
    console.log('\nTop-level fields available:', Object.keys(data));
    
  } catch (error) {
    console.error(`Error fetching ${name}:`, error.message);
  }
}

// Test all endpoints
async function exploreAll() {
  for (const [name, url] of Object.entries(endpoints)) {
    await exploreEndpoint(name, url);
    await new Promise(resolve => setTimeout(resolve, 1000)); // Rate limiting
  }
}

// Run exploration
exploreAll();