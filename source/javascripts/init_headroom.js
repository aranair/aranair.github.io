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

//   $("div.pagination").headroom({
//     "offset": 205,
//     "tolerance": 5,
//     "classes": {
//       "initial": "animated",
//       "pinned": "slideInRight",
//       "unpinned": "slideOutRight"
//     }
//   });

//   $("div.tags").headroom({
//     "offset": 205,
//     "tolerance": 5,
//     "classes": {
//       "initial": "animated",
//       "pinned": "slideInRight",
//       "unpinned": "slideOutRight"
//     }
//   });
});
