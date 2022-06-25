import { Observable as O } from '../rxjs'

function display(msg) {
  if (!document.hasFocus()) {
    const notif = new Notification('Stonix', { body: msg, tag: 'stonix-msg', icon: 'notification.png' })
    notif.onclick = _ => window.focus()
  }
}

module.exports = msg$ => (
  O.from(msg$).subscribe(display)
, O.empty()
)
