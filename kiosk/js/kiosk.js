// JavaScript Document

var cos_weekday = [
  'SUNDAY', 'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY'
];
// var cos_hdoc = null;
var cos_clock = null;
var cos_timer = null;
var cos_time_slots = [];
var cos_prior_time = null;
var cos_active_time = null;
var cos_next_time = null;
var cos_active_row = null;
var cos_active_desc = null;

// From joki @ stackoverflow: https://stackoverflow.com/a/41956372
/**
 * Return 0 <= i <= array.length such that !pred(array[i - 1]) &&
 * pred(array[i]).
 */
function binarySearch(array, pred) {
  let lo = -1, hi = array.length;
  while (1 + lo < hi) {
    const mi = lo + ((hi - lo) >> 1);
    if (pred(array[mi])) {
      hi = mi;
    } else {
      lo = mi;
    }
  }
  return hi;
}

/**
 * Return i such that array[i - 1] < item <= array[i].
 */
function lowerBound(array, item) {
  return binarySearch(array, j => item <= j);
}

/**
 * Return i such that array[i - 1] <= item < array[i].
 */
function upperBound(array, item) {
  return binarySearch(array, j => item < j);
}
// End from joki @ stackoverflow: https://stackoverflow.com/a/41956372

function cos_set_current(time_slot) {
  if (cos_time_slots.empty) {
    return;
  }
  if (cos_prior_time != null &&
      (cos_active_time == null || time_slot < cos_next_time)) {
    return;
  }
  const idToken = lowerBound(cos_time_slots, time_slot);

  cos_prior_time = cos_time_slots[idToken < 4 ? 0 : idToken - 4];
  cos_active_time = cos_time_slots[idToken < 1 ? 0 : idToken - 1];
  cos_next_time =
      idToken < cos_time_slots.length ? cos_time_slots[idToken] : null;

  if (cos_active_row != null) {
    cos_active_row.classList.remove('activeRow');
  }
  if (cos_active_desc != null) {
    cos_active_desc.classList.add('inactiveDesc');
  }
  cos_active_row = document.getElementById('sched_id_' + cos_active_time);
  cos_active_desc = document.getElementById('desc_id_' + cos_active_time);
  if (cos_active_row != null) {
    cos_active_row.classList.add('activeRow');
  }
  if (cos_active_desc != null) {
    cos_active_desc.classList.remove('inactiveDesc');
  }
  const scroll_row = document.getElementById('sched_id_' + cos_prior_time);
  if (scroll_row != null) {
    scroll_row.scrollIntoView(true);
  }
}

function cos_clock_callback() {
  const currentTime = new Date();

  const numDay = currentTime.getDay();
  const numHour = currentTime.getHours();
  const numMinutes = currentTime.getMinutes();
  const numSeconds = currentTime.getSeconds();

  const timeOfDay = (numHour < 12) ? 'AM' : 'PM';
  const stringHour =
      '' + (numHour == 0 ? 12 : numHour > 12 ? numHour - 12 : numHour);
  const stringMinutes = (numMinutes < 10 ? '0' : '') + numMinutes;
  const stringSeconds = (numSeconds < 10 ? '0' : '') + numSeconds;

  // Compose the string for display
  const currentTimeString = cos_weekday[numDay] + ' ' + stringHour + ':' +
      stringMinutes + ':' + stringSeconds + ' ' + timeOfDay;

  // Get the index
  const relDay = (numDay < 5 ? numDay + 2 : numDay - 5);
  cos_set_current((((relDay * 24) + numHour) * 60) + numMinutes);

  // Update the time display
  if (cos_clock != null) {
    cos_clock.innerHTML = currentTimeString;
  }
}

function cos_loaded() {
  cos_clock = document.getElementById('current_time');

  const slots = document.getElementsByClassName('schedRowTimeSlot');
  cos_time_slots = [];
  cos_prior_time = null;
  cos_active_time = null;
  cos_next_time = null;

  const num_slots = slots.length;
  for (var i = 0; i < num_slots; i++) {
    const elem = slots[i];
    const id = elem.id;
    if (id == null) {
      continue;
    }
    const time_txt = id.split('_').pop();
    if (time_txt != null && time_txt != '') {
      cos_time_slots.push(1 * time_txt);
    }
  }
  cos_time_slots.sort(function(a, b) {
    return a - b
  });

  cos_clock_callback();
  cos_timer = setInterval(cos_clock_callback, 1000);
}

function cos_unloaded() {
  clearInterval(cos_timer);
  cos_timer = null;
}

window.onload = cos_loaded;
window.onunload = cos_unloaded;
