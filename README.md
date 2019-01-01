# Weekly Budget Tracking App

A simplistic mobile app that allocates predefined budget weekly and tracks the left amount. The app can be built for both Android and iOS, thanks to the Flutter development framework.

## What is the use case?

I have always wanted a simple budget tracking app. I don't need to see the detailed list of expenses I have made in the past. I don't care about expense report or analysis. All I want is a plain number telling me how much budget I have left for the week, and the interface should _minimize_ the number of clicks I need to make to input my expense in order to make the task as effortless as possible - after all, if a routine task takes too much work, and in this case every click counts, we aren't going to keep up, are we?

## How to use this app?

1. __menu -> Set weekly budget:__ Set a weekly budget, the default being $100, to be added to the tracked amount weekly. The tracked amount will be carried over to the next week.
2. __menu -> Rest available fund:__ Reset the tracked amount to the weekly budget.
3. __down arrow button:__ Deduct expenses. This is the main focus of the app.
4. __up arrow button:__ Add more fund, for cases when you get some additional budget to spend.
5. __Triangle to the left of the tracked amount, when applicable:__ Undo the last manual transaction (3 or 4), in case you input a wrong amount.
6. __Triangle to the right of hte tracked amount, when applicable:__ Redo the last undo (5).
7. __menu -> Show info:__ Display the currently set weekly budget, and when the budget will be loaded again.

## How does it look and feel?

<p align="center">
    <img src="weekly-budget-demo.gif">
</p>
