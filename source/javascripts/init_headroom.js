$(document).ready(function() {
  $("#header").headroom({
    "offset": 205,
    "tolerance": {
      "up": 5,
      "down": 0
    },
    "classes": {
      "initial": "animated",
      "pinned": "slideInDown",
      "unpinned": "slideOutUp"
    }
  });

  $("div.pagination").headroom({
    "offset": 205,
    "tolerance": {
      "up": 5,
      "down": 0
    },
    "classes": {
      "initial": "animated",
      "pinned": "fadeIn",
      "unpinned": "fadeOut"
    }
  });

  $("div.tags").headroom({
    "offset": 205,
    "tolerance": {
      "up": 5,
      "down": 0
    },
    "classes": {
      "initial": "animated",
      "pinned": "fadeIn",
      "unpinned": "fadeOut"
    }
  });
});
