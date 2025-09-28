const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs').promises;
const aiService = require('./aiService');
const crypto = require('crypto');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json({ limit: '256kb' })); // Add size limit

// Add security headers middleware
app.use((req, res, next) => {
  res.set({
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'DENY',
    'X-XSS-Protection': '1; mode=block'
  });
  next();
});

// Load mock data files
let claims = [];
let notes = {};

const loadMockData = async () => {
  try {
    const claimsData = await fs.readFile(path.join(__dirname, '../mocks/claims.json'), 'utf8');
    claims = JSON.parse(claimsData);
    
    const notesData = await fs.readFile(path.join(__dirname, '../mocks/notes.json'), 'utf8');
    notes = JSON.parse(notesData);
    
    console.log(`Loaded ${claims.length} claims and ${Object.keys(notes).length} notes`);
  } catch (error) {
    console.error('Error loading mock data:', error);
    process.exit(1);
  }
};

// Request logging middleware
app.use((req, res, next) => {
  const start = Date.now();
  const requestId = crypto.randomUUID();
  req.requestId = requestId;
  res.setHeader('X-Request-ID', requestId);
  res.on('finish', () => {
    const duration = Date.now() - start;
    console.log(
      `Request completed - RequestId: ${requestId}; Method: ${req.method}; Path: ${req.path}; Status: ${res.statusCode}; Duration: ${duration}ms`
    );
  });
  next();
});

// Health check endpoint
app.get('/health', async (req, res) => {
  const health = {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    service: 'claim-status-api',
    version: '1.0.0',
    dependencies: {
      mockData: {
        claims: claims.length,
        notes: Object.keys(notes).length
      },
      azureOpenAI: !!aiService.client ? 'connected' : 'mock_mode'
    }
  };
  
  res.json(health);
});

// Add after middleware setup in src/server.js
const CLAIM_ID_REGEX = /^CLM\d{3}$/;

function validateClaimId(req, res, next) {
  const { id } = req.params;
  if (!CLAIM_ID_REGEX.test(id)) {
    return res.status(400).json({
      error: 'Invalid claim ID format. Expected CLM### (e.g., CLM001)',
      claimId: id,
      requestId: req.requestId
    });
  }
  next();
}

// GET /claims/{id} - Returns claim status from claims.json
app.get('/claims/:id', validateClaimId, async (req, res) => {
  try {
    const claimId = req.params.id;
    const claim = claims.find(c => c.id === claimId);
    
    if (!claim) {
      return res.status(404).json({
        error: 'Claim not found',
        claimId: claimId
      });
    }
    
    console.log(`Claim accessed - RequestId: ${req.requestId}; ClaimId: ${claimId}; ClaimType: ${claim.type}`);
    res.json(claim);
  } catch (error) {
    console.error('Error retrieving claim:', error);
    res.status(500).json({
      error: 'Internal server error',
      message: error.message
    });
  }
});

// Replace summarize endpoint block
app.post('/claims/:id/summarize', validateClaimId, async (req, res) => {
  try {
    const claimId = req.params.id;

    const claim = claims.find(c => c.id === claimId);
    if (!claim) {
      return res.status(404).json({ error: 'Claim not found', claimId });
    }

    const claimNotes = notes[claimId];
    if (!claimNotes) {
      return res.status(404).json({ error: 'No notes found for claim', claimId });
    }

    const startTime = Date.now();
    const notesText = Array.isArray(claimNotes.notes) ? claimNotes.notes.join(' ') : String(claimNotes.notes || '');
    const result = await aiService.generateSummary(claim, notesText);
    const duration = Date.now() - startTime;

    console.log(
      `AI summary generated - RequestId: ${req.requestId}; ClaimId: ${claimId}; ClaimType: ${claim.type}; ProcessingTime: ${duration}ms; TokensUsed: ${result.usageTokens}`
    );

    res.json({
      claimId,
      summary: result.summary,
      customerSummary: result.customerSummary,
      adjusterSummary: result.adjusterSummary,
      nextStep: result.nextStep,
      generatedAt: new Date().toISOString()
    });
  } catch (error) {
    const errorType = error.name || 'Error';
    console.error(
      `AI service error - RequestId: ${req.requestId}; ClaimId: ${req.params.id}; ErrorType: ${errorType}; Message: ${error.message}`
    );
    res.status(500).json({
      error: 'Failed to generate summary',
      requestId: req.requestId
    });
  }
});

// Start server after loading mock data
const startServer = async () => {
  await loadMockData();
  
  app.listen(PORT, () => {
    console.log(`Claim Status API running on port ${PORT}`);
    console.log(`Health check: http://localhost:${PORT}/health`);
    console.log(`Available claims: ${claims.map(c => c.id).join(', ')}`);
  });
};

startServer().catch(console.error);

module.exports = app;