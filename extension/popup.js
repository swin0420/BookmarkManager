let isExporting = false;

document.addEventListener('DOMContentLoaded', async () => {
  const exportBtn = document.getElementById('exportBtn');
  const openAppBtn = document.getElementById('openAppBtn');
  const statusDiv = document.getElementById('status');
  const btnText = document.getElementById('btnText');
  const btnSpinner = document.getElementById('btnSpinner');
  const progressDiv = document.getElementById('progress');
  const autoScrollCheckbox = document.getElementById('autoScroll');
  const continueFromLastCheckbox = document.getElementById('continueFromLast');
  const lastExportInfo = document.getElementById('lastExportInfo');
  const lastTweetIdSpan = document.getElementById('lastTweetId');

  // Load and display last saved tweet ID
  const stored = await chrome.storage.local.get('lastTweetId');
  if (stored.lastTweetId) {
    lastTweetIdSpan.textContent = stored.lastTweetId;
    lastExportInfo.style.display = 'block';
  }

  // Check if we're on the bookmarks page
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  const isBookmarksPage = tab.url?.includes('/i/bookmarks');

  if (isBookmarksPage) {
    exportBtn.disabled = false;
    statusDiv.textContent = 'Ready to export bookmarks to the app.';
    statusDiv.className = 'status info';
  } else {
    statusDiv.innerHTML = 'Please navigate to <a href="https://x.com/i/bookmarks" target="_blank" style="color: #1DA1F2;">x.com/i/bookmarks</a> first.';
    statusDiv.className = 'status warning';
  }

  // Export button click handler
  exportBtn.addEventListener('click', async () => {
    if (isExporting) return;
    isExporting = true;

    exportBtn.disabled = true;
    btnText.textContent = 'Exporting...';
    btnSpinner.style.display = 'block';
    progressDiv.style.display = 'block';

    // Get last tweet ID if continuing from last export
    let lastTweetId = null;
    if (continueFromLastCheckbox.checked) {
      if (stored.lastTweetId) {
        lastTweetId = stored.lastTweetId;
        progressDiv.textContent = 'Searching for last saved position...';
      } else {
        progressDiv.textContent = 'No previous export found, starting fresh...';
      }
    } else {
      progressDiv.textContent = 'Scanning bookmarks...';
    }

    try {

      const [result] = await chrome.scripting.executeScript({
        target: { tabId: tab.id },
        func: scrapeBookmarks,
        args: [autoScrollCheckbox.checked, lastTweetId],
      });

      let bookmarks = result.result;
      console.log(`Scraper returned: ${bookmarks ? bookmarks.length : 0} bookmarks`);

      if (!bookmarks || bookmarks.length === 0) {
        if (lastTweetId) {
          throw new Error('No new bookmarks found after last saved position. You may be up to date!');
        }
        throw new Error('No bookmarks found. Try scrolling down to load more.');
      }

      // Filter out bookmarks with missing required fields
      const beforeFilter = bookmarks.length;
      bookmarks = bookmarks.filter(b => b.tweet_id && b.author_handle && b.content);
      console.log(`After filter: ${bookmarks.length} (removed ${beforeFilter - bookmarks.length} invalid)`);

      if (bookmarks.length === 0) {
        throw new Error('No valid bookmarks found. Twitter may have changed their layout.');
      }
      progressDiv.textContent = `Found ${bookmarks.length} bookmarks. Sending to app...`;

      // Save to JSON file
      const jsonData = JSON.stringify(bookmarks);
      console.log(`📦 Exporting ${bookmarks.length} bookmarks to JSON file`);

      const blob = new Blob([jsonData], { type: 'application/json' });
      const blobUrl = URL.createObjectURL(blob);

      const a = document.createElement('a');
      a.href = blobUrl;
      a.download = 'bookmarks-export.json';
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(blobUrl);

      // Save the last tweet ID for "continue from last" feature
      if (bookmarks.length > 0) {
        const lastExportedTweetId = bookmarks[bookmarks.length - 1].tweet_id;
        await chrome.storage.local.set({ lastTweetId: lastExportedTweetId });
        lastTweetIdSpan.textContent = lastExportedTweetId;
        lastExportInfo.style.display = 'block';
        console.log(`💾 Saved last tweet ID: ${lastExportedTweetId}`);
      }

      statusDiv.innerHTML = `Exported ${bookmarks.length} bookmarks.<br>Use "Import Database" in the app to import.`;
      statusDiv.className = 'status success';

      progressDiv.style.display = 'none';
    } catch (error) {
      statusDiv.textContent = error.message;
      statusDiv.className = 'status error';
      progressDiv.style.display = 'none';
    } finally {
      isExporting = false;
      exportBtn.disabled = !isBookmarksPage;
      btnText.textContent = 'Send to App';
      btnSpinner.style.display = 'none';
    }
  });

  // Open app button - now opens the native app
  openAppBtn.addEventListener('click', () => {
    window.location.href = 'bookmarkmanager://open';
  });
});

// This function runs in the context of the Twitter page - exports from current scroll position
async function scrapeBookmarks(autoScroll, lastTweetId) {
  const bookmarks = [];
  const seenIds = new Set();
  let foundLastTweet = !lastTweetId; // If no lastTweetId, start collecting immediately
  let passedLastTweet = false;

  const extractTweets = async () => {
    const articles = document.querySelectorAll('article[data-testid="tweet"]');

    for (const article of articles) {
      try {
        // Get tweet link to extract ID
        const tweetLink = article.querySelector('a[href*="/status/"]');
        if (!tweetLink) continue;

        const urlMatch = tweetLink.href.match(/\/status\/(\d+)/);
        if (!urlMatch) continue;

        const tweetId = urlMatch[1];
        if (seenIds.has(tweetId)) continue;
        seenIds.add(tweetId);

        // If we're continuing from last export, skip until we find the last saved tweet
        if (!foundLastTweet) {
          if (tweetId === lastTweetId) {
            foundLastTweet = true;
            passedLastTweet = true;
            console.log(`🎯 Found last saved tweet: ${tweetId}, will collect from here`);
          }
          continue; // Skip this tweet (already exported before)
        }

        // Extract author info - try multiple methods
        let authorHandle = '';
        let authorName = '';
        let authorAvatar = '';

        // Method 1: Get from tweet URL
        const tweetUrlMatch = tweetLink.href.match(/\/([^/]+)\/status\/\d+/);
        if (tweetUrlMatch) {
          authorHandle = tweetUrlMatch[1];
        }

        // Method 2: Get author name and avatar from user links
        const userLinks = article.querySelectorAll('a[href^="/"]');
        for (const link of userLinks) {
          const href = link.getAttribute('href');
          if (href && href.match(/^\/[^/]+$/) && !href.includes('/status/') && !href.startsWith('/i/')) {
            if (!authorHandle) authorHandle = href.slice(1);
            const nameSpan = link.querySelector('span');
            if (nameSpan && !authorName) {
              authorName = nameSpan.textContent || '';
            }
            const avatar = link.querySelector('img');
            if (avatar && !authorAvatar) {
              authorAvatar = avatar.src;
            }
            if (authorHandle && authorName) break;
          }
        }

        // Fallback for author name
        if (!authorName) authorName = authorHandle;

        // Extract tweet text - try multiple selectors
        let content = '';

        // Check for "Show more" - if present, click to expand
        const showMoreBtn = article.querySelector('[data-testid="tweet-text-show-more-link"]');
        if (showMoreBtn) {
          showMoreBtn.click();
          await new Promise(r => setTimeout(r, 300)); // Wait for expansion
        }

        const tweetTextDiv = article.querySelector('[data-testid="tweetText"]');
        if (tweetTextDiv) {
          // Get all text nodes including spans to preserve full content
          content = tweetTextDiv.innerText || tweetTextDiv.textContent || '';
        }

        // If no text found, check for other text containers
        if (!content) {
          const altTextDiv = article.querySelector('div[lang]');
          if (altTextDiv) {
            content = altTextDiv.innerText || altTextDiv.textContent || '';
          }
        }

        // Only mark as media only if truly no text and has media - detect type
        if (!content.trim()) {
          const hasVideo = article.querySelector('video') || article.querySelector('[data-testid="videoPlayer"]');
          const hasImage = article.querySelector('img[src*="pbs.twimg.com/media"]');
          const hasCard = article.querySelector('[data-testid="card.wrapper"]');

          if (hasVideo) {
            content = '[video]';
          } else if (hasCard) {
            content = '[link/article]';
          } else if (hasImage) {
            content = '[image]';
          } else {
            content = '[no content]';
          }
        }

        // Extract timestamp
        const timeEl = article.querySelector('time');
        const postedAt = timeEl ? timeEl.getAttribute('datetime') : new Date().toISOString();

        // Extract media URLs (images, video thumbnails, GIFs)
        const mediaUrls = [];

        // Images from tweet media
        const images = article.querySelectorAll('img[src*="pbs.twimg.com/media"]');
        images.forEach((img) => {
          if (!mediaUrls.includes(img.src)) mediaUrls.push(img.src);
        });

        // Video/GIF thumbnails (poster images)
        const videos = article.querySelectorAll('video');
        videos.forEach((video) => {
          if (video.poster && !mediaUrls.includes(video.poster)) {
            mediaUrls.push(video.poster);
          }
        });

        // Any image inside video player or media container
        const mediaContainers = article.querySelectorAll('[data-testid="videoPlayer"], [data-testid="tweetPhoto"], [aria-label*="media"], div[data-testid="card.wrapper"]');
        mediaContainers.forEach((container) => {
          const imgs = container.querySelectorAll('img');
          imgs.forEach((img) => {
            if (img.src && img.src.includes('twimg.com') && !mediaUrls.includes(img.src)) {
              mediaUrls.push(img.src);
            }
          });
        });

        // Fallback: any twimg image in the article that looks like media
        if (mediaUrls.length === 0) {
          const allImgs = article.querySelectorAll('img[src*="twimg.com"]');
          allImgs.forEach((img) => {
            // Skip profile pics and emoji
            if (img.src.includes('/profile_images/') || img.src.includes('/emoji/')) return;
            if (img.width > 100 || img.height > 100) {
              if (!mediaUrls.includes(img.src)) mediaUrls.push(img.src);
            }
          });
        }

        // Build tweet URL
        const url = `https://x.com/${authorHandle}/status/${tweetId}`;

        bookmarks.push({
          tweet_id: tweetId,
          author_handle: authorHandle,
          author_name: authorName,
          author_avatar: authorAvatar,
          content: content,
          posted_at: postedAt,
          bookmarked_at: new Date().toISOString(),
          url: url,
          media_urls: mediaUrls,
        });
      } catch (e) {
        console.error('Error extracting tweet:', e);
      }
    }
  };

  // Extract initially visible tweets
  await extractTweets();

  // Auto-scroll to load more
  if (autoScroll) {
    const scrollDelay = 1500;
    const maxScrolls = 100;
    const maxSearchScrolls = 200; // Extra scrolls allowed when searching for last tweet
    let scrollCount = 0;
    let noNewTweetsCount = 0;

    // If continuing from last, log it
    if (lastTweetId) {
      console.log(`🔍 Looking for last saved tweet: ${lastTweetId}`);
    }

    // Extract initial visible tweets
    await extractTweets();
    console.log(`Initial: ${bookmarks.length} bookmarks${!foundLastTweet ? ' (still searching for last tweet)' : ''}`);

    // Keep scrolling until we find the last tweet, then collect more
    let collectingScrolls = 0; // Count scrolls after finding last tweet

    while (scrollCount < maxSearchScrolls && noNewTweetsCount < 3) {
      const beforeCount = bookmarks.length;
      const wasFound = foundLastTweet;

      // Scroll down by 2x viewport height to cover more ground
      window.scrollBy(0, window.innerHeight * 2);

      // Wait for new content to load
      await new Promise(r => setTimeout(r, scrollDelay));

      // Extract newly visible tweets
      await extractTweets();

      const newFound = bookmarks.length - beforeCount;

      // If we just found the last tweet, log it
      if (!wasFound && foundLastTweet) {
        console.log(`✅ Found last tweet at scroll ${scrollCount + 1}, now collecting new bookmarks`);
      }

      console.log(`Scroll ${scrollCount + 1}: +${newFound} new (${bookmarks.length} total)${!foundLastTweet ? ' [searching...]' : ''}`);

      // Only count "no new tweets" if we've already found the last tweet (or not searching)
      if (foundLastTweet) {
        collectingScrolls++;
        if (newFound === 0) {
          noNewTweetsCount++;
        } else {
          noNewTweetsCount = 0;
        }

        // Once we've done enough collecting scrolls, we can stop
        if (collectingScrolls >= maxScrolls) {
          console.log(`Completed ${maxScrolls} collection scrolls after finding last position`);
          break;
        }
      }

      scrollCount++;
    }

    // If we never found the last tweet, it may have been deleted/unbookmarked
    // Reset and collect from current position
    if (!foundLastTweet) {
      console.warn(`⚠️ Could not find last saved tweet after ${scrollCount} scrolls. It may have been removed.`);
      console.log(`Starting fresh collection from current position...`);
      foundLastTweet = true;

      // Do additional scrolls to collect tweets
      let extraScrolls = 0;
      let noNewCount = 0;
      while (extraScrolls < maxScrolls && noNewCount < 3) {
        const beforeCount = bookmarks.length;
        window.scrollBy(0, window.innerHeight * 2);
        await new Promise(r => setTimeout(r, scrollDelay));
        await extractTweets();
        const newFound = bookmarks.length - beforeCount;
        console.log(`Extra scroll ${extraScrolls + 1}: +${newFound} new (${bookmarks.length} total)`);
        if (newFound === 0) noNewCount++;
        else noNewCount = 0;
        extraScrolls++;
      }
    }

    console.log(`Final count after auto-scroll: ${bookmarks.length} bookmarks`);
  }

  console.log(`Returning ${bookmarks.length} bookmarks from scraper`);
  return bookmarks;
}
