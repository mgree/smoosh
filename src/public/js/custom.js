
// Submit the expansion form
$("#expansionForm").submit(function(e) {
  var url = "/expand/submit";

  var populateResults = function(data) {
    parent = $("#submit-result");
    console.log(parent);

    for(var i = 0; i < data.length; i++) {
      var step = data[i];
      console.log(step);

      var stepType = step['term']['tag'];
      var stepFields = step['term']['f'];
      var stepWords = step['term']['w'];

      var htmlString = "<div class='expansion-step' style='margin-bottom: 20px;'>"
      htmlString += "<div>Env: " + JSON.stringify(step['env']) + "</div>";
      htmlString += "<div>" + stepType + " Fields: " + JSON.stringify(stepFields) + "</div>";
      htmlString += "<div>Words: " + JSON.stringify(stepWords) + "</div>";
      htmlString += "</div>"

      parent.append(htmlString);
    }
  }

  $.ajax({
    type: "POST",
    url: url,
    data: $("#expansionForm").serialize(),
    success: function(data) {
      populateResults(JSON.parse(data))
    },
  });

  e.preventDefault();
});
