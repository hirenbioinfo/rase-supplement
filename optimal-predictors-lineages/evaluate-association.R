#!/usr/bin/env Rscript

#
# Author:  Karel Brinda <kbrinda@hsph.harvard.edu>
#
# License: MIT
#

library(RColorBrewer)
library(data.table)

set.seed(42)

get.ants <- function(df1) {
  c = colnames(df1)
  m = grepl(".*_Rr" , c, perl = T)
  c2 = c[m]
  c3 = sub("_Rr", "", c2)
  c3
}

table.cases <- function(df1, ant, norm = NA) {
  # Load table with lineage cases. Normalize to norm isolates per lineage
  print("")
  print(paste("-------", ant, "-------"))
  print("")
  df2 = subset(df1, select = c("lineage", "count", paste0(ant, "_Rr"), paste0(ant, "_Ss")))
  print(df2)
  colnames(df2)[3] = "R"
  colnames(df2)[4] = "S"
  
  if (!is.na(norm)) {
    df2$R = norm * df2$R / df2$count
    df2$S = norm * df2$S / df2$count
    df2$count = df2$S + df2$R
  }
  
  df2$prop = df2$R / df2$count
  print(df2)
  
  df2
}

table.cumul <- function(df1) {
  df2 = df1[order(-df1[, "prop"]), ]
  df3 = subset(df2, select = c("lineage", "R", "S"))
  df4 = rbind(c(0, 0), df3)
  df5 = cumsum(df4)
  df5$lineage = c(0, df2$lineage)
  rownames(df5) <- NULL
  print(df5)
  df5
}

table.roc <- function(df1) {
  setnames(df1, old = "R", new = "TP")
  setnames(df1, old = "S", new = "FP")
  df1$FN = max(df1$TP) - df1$TP
  df1$TN = max(df1$FP) - df1$FP
  print(df1)
  df1
}

max.res.isolates <- function(df, ants, norm) {
  res = c()
  for (ant in ants) {
    dfc = table.cases(df, ant, norm)
    res = c(res, sum(dfc$R))
  }
  max(res)
}

plot.toc = function(df,
  all.ants = NA,
  main = NA,
  norm = NA,
  y.max = NA,
  xlab = "autocomplete",
  ylab = "autocomplete") {
  ants <- get.ants(df)
  if (is.na(all.ants)) {
    all.ants = ants
  }
  l = length(all.ants)
  palette(brewer.pal(l, "Paired"))
  
  if (identical(xlab, "autocomplete")) {
    if (is.na(norm)) {
      xlab = "#isolates"
    }
    else {
      xlab = "#lineages"
    }
  }
  
  if (identical(ylab, "autocomplete")) {
    if (is.na(norm)) {
      ylab = "cumulative no. of resistant isolates"
    } else {
      ylab = "cumulative no. of fully resistant lineages"
    }
  }
  
  
  if (is.na(norm)) {
    x.max = sum(df$count)
  }
  else {
    x.max = norm * length(df[, 1])
  }
  
  if (is.na(y.max)) {
    y.max = 1.2 * max.res.isolates(df, ants, norm)
  }
  
  plot(
    NA,
    xlim = c(0, x.max),
    ylim = c(0, y.max),
    xlab = xlab,
    ylab = ylab,
    main = main
    #axes = F
  )
  
  i = 1
  mask = c()
  for (a in all.ants) {
    if (a %in% ants) {
      mask = c(mask, T)
      
      dfc = table.cases(df, a, norm)
      dfl = table.cumul(dfc)
      dfr = table.roc(dfl)
      
      points(dfr$TP + dfr$FP,
        dfr$TP,
        #pch = NA,
        pch = i,
        col = i)
      lines(dfr$TP + dfr$FP,
        dfr$TP,
        col = i)
      
      m = max(dfr$TP)
      lines(c(m, x.max), c(m, m), lt = 6)
      
    }
    else{
      mask = c(mask, F)
      
    }
    i = i + 1
  }
  
  lines(c(0, y.max), c(0, y.max), lt = 2)
  lines(c(0, x.max), c(0, 0), lt = 1)
  
  legend(
    "topleft",
    legend = c(all.ants[mask], "fully res.", "fully sus.", "best"),
    col = c(seq(l)[mask], "black", "black", "black"),
    pch = c(seq(l)[mask], NA, NA, NA),
    lty = c(rep(1, l)[mask], 2, 3, 6),
    bg = "white"
  )
}

plot.roc = function(df,
  all.ants = NA,
  norm = NA,
  xlab = "FPR (1-specificity)",
  ylab = "TPR (sensitivity)",
  xlim = c(0, 1),
  ylim = c(0, 1),
  ...) {
  ants <- get.ants(df)
  if (identical(all.ants, NA)) {
    all.ants = ants
  }
  l = length(all.ants)
  palette(brewer.pal(l, "Paired"))
  
  plot(
    NA,
    xlim = xlim,
    ylim = ylim,
    xlab = xlab,
    ylab = ylab,
    ...
  )
  
  lines(c(0, 1), c(0, 1), lt = 2)
  lines(c(0, 0), c(0, 1), lt = 6)
  lines(c(0, 1), c(1, 1), lt = 6)
  
  i = 1
  mask = c()
  for (a in all.ants) {
    if (a %in% ants) {
      mask = c(mask, T)
      
      dfc = table.cases(df, a, norm)
      dfl = table.cumul(dfc)
      dfr = table.roc(dfl)
      
      points(
        dfr$FP / (dfr$FP + dfr$TN),
        dfr$TP / (dfr$TP + dfr$FN),
        pch = i,
        col = i,
        type = "b"
      )
    }
    else{
      mask = c(mask, F)
      
    }
    i = i + 1
  }
  
  legend(
    "bottomright",
    legend = c(all.ants[mask], "random", "best"),
    col = c(seq(l)[mask], "black", "black"),
    pch = c(seq(l)[mask], NA, NA),
    lty = c(rep(1, l)[mask], 2, 6)
  )
}

integrate.roc <- function(fpr, tpr) {
  x = fpr
  y = tpr
  delta.x = diff(x)
  avg.y = (head(y, n = -1) + tail(y, n = -1)) / 2
  sum(delta.x * avg.y)
}

ants.to.aucs <- function(df, all.ants = NA, norm = NA)
{
  #area under roc curve for all antibiotics
  ants <- get.ants(df)
  if (identical(all.ants, NA)) {
    all.ants = ants
  }
  aucs = c()
  i = 1
  cols = c()
  for (a in all.ants) {
    if (a %in% ants) {
      cols = c(cols, i)
      dfc = table.cases(df, a, norm)
      dfl = table.cumul(dfc)
      dfr = table.roc(dfl)
      
      auc = integrate.roc(dfr$FP / (dfr$FP + dfr$TN),
        dfr$TP / (dfr$TP + dfr$FN))
      aucs = c(aucs, auc)
    }
    i = i + 1
  }
  dfa = data.frame(v1 = ants, v2 = aucs, v3 = cols)
  dfa
}

plot.auc <- function(df,
  all.ants = NA,
  norm = NA,
  ylim = c(0.5, 1),
  annotate = F,
  ...)
{
  ants <- get.ants(df)
  aucs = ants.to.aucs(df, all.ants, norm)
  x = barplot(
    aucs$v2,
    names.arg = aucs$v1,
    col = aucs$v3,
    ylim = ylim,
    xpd = F,
    ...
  )
  text(x, aucs$v2, labels = round(aucs$v2, 2))
  abline(h = seq(0.5, 1.0, 0.1), lt = 2)
  offset = 1.4
  if (annotate) {
    text(
      length(aucs[, 1]) + offset,
      seq(.55, .95, 0.10),
      c("fail", "poor", "fair", "good", "excellent"),
      pos = 2
    )
  }
}

###########
# DEPREC
###########

plot.yonlike <-
  function(fn, xlab = "#lineages", ylab = "cumulative fraction of total resistant isolates", ...) {
    df <- read.delim(fn)
    
    df2 = transpose(df)
    l = length(colnames(df2))
    colnames(df2) = df2[1, ] # the first row will be the header
    
    df2 = df2[-1, ]          # removing the first row.
    
    cols.act = colSums(is.na(df2)) == 0 # active columns, to be plotted
    
    
    palette(brewer.pal(l, "Paired"))
    matplot(
      df2,
      xlab = xlab,
      ylab = ylab,
      type = "b",
      col = seq(l),
      pch = seq(l),
      lty = 1,
      axes = F,
      ...
    )
    
    axis(
      side = 1,
      at = 1:nrow(df2),
      labels = 0:(nrow(df2) - 1)
    )
    axis(2)
    axis(
      side = 3,
      at = 1:nrow(df2),
      labels = F,
      col.ticks = NA
    )
    axis(4, labels = F, col.ticks = NA)
    
    legend(
      "bottomright",
      legend = colnames(df2)[cols.act],
      col = seq(l)[cols.act],
      pch = seq(l)[cols.act]
    )
  }
